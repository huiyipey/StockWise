const {createHash} = require('node:crypto');
const {HttpsError} = require('firebase-functions/v2/https');

function displayStoreName(value) {
  return typeof value === 'string' ? value.trim().replace(/\s+/gu, ' ') : '';
}
function normalizedStoreName(value) {
  return displayStoreName(value).normalize('NFKC').toLowerCase();
}
function storeNameKey(value) {
  return createHash('sha256').update(normalizedStoreName(value)).digest('hex');
}

function storeDetails(data) {
  const name = displayStoreName(data?.name);
  const shopAddress = typeof data?.shopAddress === 'string' ? data.shopAddress.trim() : '';
  if (name.length < 2 || name.length > 80) {
    throw new HttpsError('invalid-argument', 'Enter a store name of 2–80 characters.');
  }
  if (!shopAddress || shopAddress.length > 500) {
    throw new HttpsError('invalid-argument', 'Enter a shop address of 1–500 characters.');
  }
  return {name, shopAddress};
}

function createStoreHandler({db, auth, serverTimestamp}) {
  return async request => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Please sign in.');
    const {name, shopAddress} = storeDetails(request.data);
    const owner = await auth.getUser(request.auth.uid);
    if (owner.disabled) throw new HttpsError('permission-denied', 'This account is unavailable.');
    const stores = db.collection('stores');
    const store = stores.doc();
    const normalized = normalizedStoreName(name);
    const nameKey = storeNameKey(name);
    const reservation = db.collection('storeNames').doc(nameKey);
    const prefix = name.replace(/[^A-Za-z0-9]/g, '').toUpperCase().padEnd(4, 'X').slice(0, 4);
    const code = `${prefix}-${store.id.slice(0, 4).toUpperCase()}`;
    const duplicate = () => new HttpsError('already-exists', 'This store name already exists. Please choose another name.');
    await db.runTransaction(async tx => {
      const registered = await tx.get(reservation);
      if (registered.exists) {
        const previous = await tx.get(stores.doc(registered.data().storeId));
        if (previous.exists) throw duplicate();
      }
      // Includes stores created before the name registry, including inactive ones.
      // Project only names: customer addresses and contact details are not needed.
      const existing = await tx.get(stores.select('name'));
      if (existing.docs.some(doc => normalizedStoreName(doc.data().name) === normalized)) throw duplicate();
      const timestamp = serverTimestamp();
      tx.set(reservation, {storeId: store.id, normalizedName: normalized, createdAt: timestamp});
      tx.set(store, {
        name, nameLowercase: normalized, nameKey, code, shopAddress,
        ownerUid: owner.uid, email: owner.email ?? null,
        timezone: 'Asia/Kuala_Lumpur', currency: 'MYR', status: 'active',
        createdAt: timestamp, updatedAt: timestamp,
      });
      tx.set(store.collection('members').doc(owner.uid), {
        storeId: store.id, userId: owner.uid, email: owner.email ?? null,
        role: 'owner', isActive: true, joinedAt: timestamp, updatedAt: timestamp,
      });
      for (const category of ['Dairy', 'Bakery', 'Vegetables', 'Fruits', 'Meat', 'Household', 'Others']) {
        const id = category.toLowerCase();
        tx.set(store.collection('categories').doc(id), {
          storeId: store.id, name: category, slug: id, sortOrder: 0,
          isActive: true, createdAt: timestamp, updatedAt: timestamp,
        });
      }
      tx.set(store.collection('settings').doc('inventory'), {
        storeId: store.id, expiryWarningDays: [2, 3, 7], updatedAt: timestamp,
      });
      tx.set(store.collection('settings').doc('commerce'), {
        storeId: store.id, currency: 'MYR', deliveryFeeCents: 500, minimumOrderCents: 0, updatedAt: timestamp,
      });
      tx.set(db.collection('users').doc(owner.uid), {activeStoreId: store.id, updatedAt: timestamp}, {merge: true});
    });
    return {id: store.id, name, code, shopAddress, status: 'active', currency: 'MYR'};
  };
}

function updateStoreHandler({db, auth, serverTimestamp}) {
  return async request => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Please sign in.');
    const storeId = request.data?.storeId;
    if (typeof storeId !== 'string' || !/^[\w-]{1,128}$/.test(storeId)) {
      throw new HttpsError('invalid-argument', 'Select a store.');
    }
    const {name, shopAddress} = storeDetails(request.data);
    const owner = await auth.getUser(request.auth.uid);
    if (owner.disabled) throw new HttpsError('permission-denied', 'This account is unavailable.');
    const stores = db.collection('stores');
    const store = stores.doc(storeId);
    const normalized = normalizedStoreName(name);
    const nameKey = storeNameKey(name);
    return db.runTransaction(async tx => {
      const current = await tx.get(store);
      if (!current.exists) throw new HttpsError('not-found', 'This store no longer exists.');
      const data = current.data();
      const member = await tx.get(store.collection('members').doc(owner.uid));
      if (data.ownerUid !== owner.uid || member.data()?.role !== 'owner' || member.data()?.isActive !== true) {
        throw new HttpsError('permission-denied', 'Only the shop owner can edit these details.');
      }
      const nameChanged = normalizedStoreName(data.name) !== normalized;
      const nextRef = db.collection('storeNames').doc(nameKey);
      const registered = await tx.get(nextRef);
      let canReserve = true;
      if (registered.exists && registered.data().storeId !== storeId) {
        const previous = await tx.get(stores.doc(registered.data().storeId));
        canReserve = !previous.exists;
      }
      const existing = await tx.get(stores.select('name'));
      const duplicate = existing.docs.some(doc => doc.id !== storeId && normalizedStoreName(doc.data().name) === normalized);
      if (nameChanged && (!canReserve || duplicate)) {
        throw new HttpsError('already-exists', 'This store name already exists. Please choose another name.');
      }
      // Legacy duplicates may keep their current name when correcting their address.
      canReserve = canReserve && !duplicate;
      const previousKey = storeNameKey(data.name);
      const oldRef = db.collection('storeNames').doc(previousKey);
      const oldReservation = previousKey !== nameKey ? await tx.get(oldRef) : null;
      const timestamp = serverTimestamp();
      if (canReserve) {
        tx.set(nextRef, {
          storeId, normalizedName: normalized,
          createdAt: registered.exists && registered.data().storeId === storeId
            ? registered.data().createdAt ?? timestamp : timestamp,
          updatedAt: timestamp,
        });
      }
      if (oldReservation?.exists && oldReservation.data().storeId === storeId) tx.delete(oldRef);
      tx.update(store, {name, shopAddress, nameLowercase: normalized, nameKey, updatedAt: timestamp});
      return {
        id: storeId, name, shopAddress, code: data.code ?? storeId.slice(0, 6).toUpperCase(),
        status: data.status ?? 'active', currency: data.currency ?? 'MYR', logoPath: data.logoPath ?? null,
      };
    });
  };
}

module.exports = {createStoreHandler, updateStoreHandler, normalizedStoreName, storeNameKey};
