const {createHash, randomUUID} = require('node:crypto');
const {DateTime} = require('luxon');
const {shelfLife, expiryStage, operatingHours} = require('./commerce_logic');
const {inventorySnapshot} = require('./inventory_snapshot');

// Only the backend reads or writes this top-level collection. Its timestamp has a default index.
const QUEUE = 'inventoryExpirySchedule';
const PAGE_SIZE = 100;
const ZONE = 'Asia/Kuala_Lumpur';
const LEASE_MS = 10 * 60_000;

function scheduleRef(db, batchRef) {
  return db.collection(QUEUE).doc(createHash('sha256').update(batchRef.path).digest('hex'));
}

// Reminder stages change at shop opening, at midnight, or 30 minutes before closing.
// Looking ahead starts at the first possible warning day, even for multi-year shelf lives.
function nextBoundary(batch, store, now, currentStage) {
  const expiry = batch.expiryAt.toDate();
  if (expiry <= now || batch.notifyOnExpiry === false || batch.status !== 'active' || batch.quantityOnHand <= 0) return expiry;
  const hours = operatingHours(store.operatingHours);
  if (hours.closedDays.length === 7) return expiry;
  const today = DateTime.fromJSDate(now, {zone: ZONE}).startOf('day');
  const expiryDay = DateTime.fromJSDate(expiry, {zone: ZONE}).startOf('day');
  const first = expiryDay.minus({days: shelfLife(batch, now).orange});
  for (let day = first > today ? first : today; day <= expiryDay; day = day.plus({days: 1})) {
    if (hours.closedDays.includes(day.weekday)) continue;
    const minutes = [hours.opens];
    if (day >= expiryDay.minus({days: 1})) minutes.push(hours.closes - 30);
    for (const minute of minutes) {
      const at = day.plus({minutes: minute}).toJSDate();
      if (at <= now || at >= expiry) continue;
      const stage = expiryStage(batch, store, at);
      if (stage && stage !== currentStage) return at;
    }
  }
  return expiry;
}

function archiveExpired(tx, store, batchRef, batch, serverTimestamp) {
  tx.set(store.collection('inventoryArchive').doc(batchRef.id), {
    ...inventorySnapshot(batch), removedAt: serverTimestamp(), removalReason: 'expired',
  });
  if (batch.quantityOnHand > 0) {
    tx.set(store.collection('inventoryEvents').doc('expiry-' + batchRef.id), {
      storeId: store.id, batchId: batchRef.id, productId: batch.productId, productName: batch.productName,
      categoryId: batch.categoryId || 'others', eventType: 'expired', quantity: batch.quantityOnHand,
      quantityDelta: -batch.quantityOnHand, actorUid: 'system', occurredAt: serverTimestamp(),
    });
  }
  tx.delete(batchRef);
}

function inventoryExpiry({db, Timestamp, serverTimestamp, sendReminder, clock = () => new Date()}) {
  function markerFor(store, ref, batch, stage) {
    return store.collection('expiryNotifications').doc([ref.id, batch.expiryAt.toMillis(), stage].join('-'));
  }

  // Always reconcile current records, including when write triggers arrive out of order.
  async function sync(store, ref, {classify = false} = {}) {
    const job = scheduleRef(db, ref);
    return db.runTransaction(async tx => {
      const now = clock();
      const batch = (await tx.get(ref)).data();
      if (!batch?.expiryAt?.toDate) { tx.delete(job); return; }
      if (classify && batch.expiryAt.toDate() <= now) {
        archiveExpired(tx, store, ref, batch, serverTimestamp);
        tx.delete(job);
        return;
      }
      const shop = (await tx.get(store)).data();
      let due;
      if (shop?.status === 'active') {
        const stage = expiryStage(batch, shop, now);
        due = nextBoundary(batch, shop, now, stage);
        if (stage) {
          const marker = (await tx.get(markerFor(store, ref, batch, stage))).data();
          if (!marker) due = now;
          else if (marker.state === 'pending') due = new Date(Math.min(+due, Math.max(+now, marker.retryAt.toMillis())));
        }
      }
      if (classify) {
        const life = shelfLife(batch, now);
        if (batch.totalShelfLifeDays !== life.totalShelfLifeDays || batch.shelfLifeType !== life.shelfLifeType) {
          tx.update(ref, {totalShelfLifeDays: life.totalShelfLifeDays, shelfLifeType: life.shelfLifeType,
            receivedAt: batch.receivedAt || batch.createdAt || Timestamp.fromDate(now)});
        }
      }
      if (due) tx.set(job, {storeId: store.id, batchId: ref.id, nextCheckAt: Timestamp.fromDate(due)});
      else tx.delete(job);
    });
  }

  async function rescheduleStore(store) {
    const batches = store.collection('inventoryBatches');
    let cursor;
    do {
      let query = batches.select().orderBy('__name__').limit(PAGE_SIZE);
      if (cursor) query = query.startAfter(cursor);
      const page = await query.get();
      for (let start = 0; start < page.size; start += 8) {
        await Promise.all(page.docs.slice(start, start + 8).map(doc => sync(store, doc.ref)));
      }
      cursor = page.size === PAGE_SIZE ? page.docs.at(-1) : null;
    } while (cursor);
  }

  async function processJob(job) {
    const claim = await db.runTransaction(async tx => {
      const now = clock();
      const task = (await tx.get(job)).data();
      if (!task || task.nextCheckAt.toMillis() > +now) return;
      const store = db.collection('stores').doc(task.storeId);
      const ref = store.collection('inventoryBatches').doc(task.batchId);
      const shop = (await tx.get(store)).data();
      const batch = (await tx.get(ref)).data();
      if (shop?.status !== 'active' || !batch?.expiryAt?.toDate) { tx.delete(job); return; }
      if (batch.expiryAt.toDate() <= now) {
        archiveExpired(tx, store, ref, batch, serverTimestamp);
        tx.delete(job);
        return;
      }
      const stage = expiryStage(batch, shop, now);
      const next = Timestamp.fromDate(nextBoundary(batch, shop, now, stage));
      const schedule = at => tx.set(job, {storeId: store.id, batchId: ref.id, nextCheckAt: at});
      if (!stage) { schedule(next); return; }
      const marker = markerFor(store, ref, batch, stage);
      const previous = (await tx.get(marker)).data();
      // Original markers have no state and already represent a claimed notification.
      if (previous && previous.state !== 'pending') { schedule(next); return; }
      if (previous && previous.retryAt.toMillis() > +now) {
        schedule(Timestamp.fromMillis(Math.min(next.toMillis(), previous.retryAt.toMillis())));
        return;
      }
      const token = randomUUID();
      const retryAt = Timestamp.fromMillis(+now + LEASE_MS);
      tx.set(marker, {batchId: ref.id, stage, state: 'pending', token, retryAt, createdAt: previous?.createdAt || serverTimestamp()});
      tx.update(job, {token, nextCheckAt: Timestamp.fromMillis(Math.min(next.toMillis(), retryAt.toMillis()))});
      return {store, batchId: ref.id, batch, stage, now, marker, token, next};
    });
    if (!claim) return;
    await sendReminder(claim);
    await db.runTransaction(async tx => {
      const marker = (await tx.get(claim.marker)).data();
      if (marker?.token !== claim.token) return;
      const task = (await tx.get(job)).data();
      tx.set(claim.marker, {batchId: claim.batchId, stage: claim.stage, createdAt: marker.createdAt, state: 'sent'});
      if (task?.token === claim.token) {
        tx.set(job, {storeId: task.storeId, batchId: task.batchId, nextCheckAt: claim.next});
      }
    });
  }

  async function runDue() {
    const cutoff = Timestamp.fromDate(clock());
    let cursor, failed = false;
    do {
      let query = db.collection(QUEUE).where('nextCheckAt', '<=', cutoff).orderBy('nextCheckAt').limit(PAGE_SIZE);
      if (cursor) query = query.startAfter(cursor);
      const page = await query.get();
      for (const doc of page.docs) {
        try { await processJob(doc.ref); }
        catch (error) { failed = true; console.error('Inventory expiry task failed', doc.id, error.message); }
      }
      cursor = page.size === PAGE_SIZE ? page.docs.at(-1) : null;
    } while (cursor);
    if (failed) throw Error('Some inventory expiry tasks require a retry.');
  }
  return {sync, rescheduleStore, runDue};
}

module.exports = {inventoryExpiry, nextBoundary, scheduleRef, QUEUE};
