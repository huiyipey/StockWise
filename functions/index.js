const {initializeApp} = require('firebase-admin/app');
const {getFirestore, Timestamp, FieldValue} = require('firebase-admin/firestore');
const {getAuth} = require('firebase-admin/auth');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {setGlobalOptions} = require('firebase-functions/v2');
const {SecretManagerServiceClient} = require('@google-cloud/secret-manager');
const {GoogleGenAI} = require('@google/genai');
const {defineSecret} = require('firebase-functions/params');
const nodemailer = require('nodemailer');
const {createHash} = require('node:crypto');
const {range, report, csv, duePeriods, recommendations} = require('./reporting');
const {createAdminInviteHandler} = require('./admin_invites');
const {normalizeAssistantRequest, assistantReply} = require('./shopping_assistant');
const geminiApiKey = defineSecret('GEMINI_API_KEY');

initializeApp();
setGlobalOptions({region: 'asia-southeast1', maxInstances: 5});
const db = getFirestore();
exports.createAdminInvite = onCall({timeoutSeconds: 30}, createAdminInviteHandler({
  db, auth: getAuth(), serverTimestamp: () => FieldValue.serverTimestamp(),
}));
const roles = ['owner', 'admin', 'manager', 'staff'];
function storeFor(request) {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Please sign in.');
  const id = request.data?.storeId;
  if (typeof id !== 'string' || !/^[\w-]{1,128}$/.test(id)) throw new HttpsError('invalid-argument', 'Select a store.');
  return db.collection('stores').doc(id);
}
async function requireMember(store, uid) {
  const member = (await store.collection('members').doc(uid).get()).data();
  if (member?.isActive !== true || !roles.includes(member.role)) throw new HttpsError('permission-denied', 'Store team access is required.');
}
async function buildReport(store, kind, start, end) {
  if (!['sales', 'waste'].includes(kind)) throw new HttpsError('invalid-argument', 'Select sales or waste.');
  let bounds;
  try { bounds = range(start, end); } catch (error) { throw new HttpsError('invalid-argument', error.message); }
  const field = kind === 'sales' ? 'placedAt' : 'occurredAt';
  const [records, categories] = await Promise.all([
    store.collection(kind === 'sales' ? 'orders' : 'inventoryEvents')
      .where(field, '>=', Timestamp.fromDate(bounds.start)).where(field, '<', Timestamp.fromDate(bounds.end)).get(),
    store.collection('categories').get(),
  ]);
  return report(kind, records.docs.map(d => ({id: d.id, ...d.data()})), start, end,
    Object.fromEntries(categories.docs.map(d => [d.id, d.data().name])));
}
exports.getStoreReport = onCall({timeoutSeconds: 120, memory: '512MiB'}, async request => {
  const store = storeFor(request);
  await requireMember(store, request.auth.uid);
  const data = await buildReport(store, request.data.kind, request.data.start, request.data.end);
  const name = (await store.get()).data()?.name || 'Store';
  return {...data, storeName: name, csv: csv(data, name)};
});

// Credentials are read only by the server; absent configuration is reported as blocked.
async function mailTransport() {
  const project = process.env.GCLOUD_PROJECT;
  const [version] = await new SecretManagerServiceClient().accessSecretVersion({
    name: `projects/${project}/secrets/REPORT_SMTP_CONFIG/versions/latest`,
  });
  const config = JSON.parse(version.payload.data.toString());
  if (!config.host || !config.user || !config.password || !config.from) throw Error('Incomplete REPORT_SMTP_CONFIG.');
  const transport = nodemailer.createTransport({host: config.host, port: Number(config.port || 465),
    secure: config.secure !== false, auth: {user: config.user, pass: config.password},
    connectionTimeout: 15000, socketTimeout: 30000});
  return {transport, from: config.from};
}
async function teamEmails(store, ownerUid) {
  const members = await store.collection('members').get();
  const uids = new Set(ownerUid ? [ownerUid] : []);
  for (const member of members.docs) if (member.data().isActive === true && roles.includes(member.data().role)) uids.add(member.id);
  const result = new Set();
  // Auth is the authoritative source, not client-editable profile/member email fields.
  for (const uid of uids) {
    try { const user = await getAuth().getUser(uid); if (user.email && !user.disabled) result.add(user.email.toLowerCase()); }
    catch (e) { if (e.code !== 'auth/user-not-found') throw e; }
  }
  return [...result];
}
exports.emailStoreReports = onSchedule({schedule: '0 9 * * *', timeZone: 'Asia/Kuala_Lumpur',
  timeoutSeconds: 540, memory: '512MiB', maxInstances: 1, retryCount: 3}, async event => {
  const periods = duePeriods(new Date(event.scheduleTime));
  if (!periods.length) return;
  let mail;
  try { mail = await mailTransport(); }
  catch (error) {
    await db.collection('systemStatus').doc('reportEmail').set({status: 'configuration_required', updatedAt: FieldValue.serverTimestamp()});
    console.error('Report mail sender is not configured or accessible.');
    throw Error('REPORT_SMTP_CONFIG is required.');
  }
  const stores = await db.collection('stores').where('status', '==', 'active').get();
  let failed = false;
  for (const doc of stores.docs) {
    try {
      const recipients = await teamEmails(doc.ref, doc.data().ownerUid);
      for (const period of periods) for (const kind of ['waste', 'sales']) {
        const result = await buildReport(doc.ref, kind, period.start, period.end);
        for (const to of recipients) {
          const recipientId = createHash('sha256').update(to).digest('hex').slice(0, 24);
          const id = `${kind}-${period.cadence}-${period.start}-${recipientId}`;
          const run = doc.ref.collection('reportDeliveries').doc(id);
          const claimed = await db.runTransaction(async tx => {
            const state = (await tx.get(run)).data();
            // Do not resend an ambiguous SMTP attempt automatically.
            if (state && ['sent', 'sending', 'uncertain'].includes(state.status)) return state.status;
            tx.set(run, {kind, ...period, recipient: to, status: 'sending', updatedAt: FieldValue.serverTimestamp()});
            return 'claimed';
          });
          if (claimed !== 'claimed') {
            if (claimed !== 'sent') failed = true;
            continue;
          }
          try {
            await mail.transport.sendMail({from: mail.from, to,
              subject: `${doc.data().name}: ${period.cadence} ${kind} report (${period.start} to ${period.end})`,
              text: `${doc.data().name}\n${period.cadence} ${kind} report\n${period.start} through ${period.end} (Malaysia time)\n` +
                (kind === 'sales' ? `Paid orders: ${result.count}\nProduct sales: MYR ${(result.revenueCents / 100).toFixed(2)}\nDelivery: MYR ${(result.deliveryCents / 100).toFixed(2)}` : `Recorded waste: ${result.units} units`) +
                '\n\nThe full data is attached. Sales are grouped by order placement date; cancelled and unpaid orders are excluded. Waste includes recorded discard/expiry events only.',
              attachments: [{filename: `${kind}-${period.start}-${period.end}.csv`, content: csv(result, doc.data().name), contentType: 'text/csv; charset=utf-8'}]});
            await run.update({status: 'sent', updatedAt: FieldValue.serverTimestamp()});
          } catch (error) {
            await run.update({status: 'uncertain', updatedAt: FieldValue.serverTimestamp()});
            failed = true;
          }
        }
      }
    } catch (error) { console.error('Store report failed', doc.id, error.code || 'error'); failed = true; }
  }
  mail.transport.close();
  await db.collection('systemStatus').doc('reportEmail').set({status: failed ? 'delivery_errors' : 'ready', updatedAt: FieldValue.serverTimestamp()});
  if (failed) throw Error('Some report deliveries require review.');
});

async function assistantContext(store, uid) {
  const [stock, orders, categories] = await Promise.all([
    store.collection('inventoryBatches').where('status', '==', 'active').orderBy('expiryAt').limit(150).get(),
    store.collection('orders').where('userId', '==', uid).orderBy('placedAt', 'desc').limit(30).get(),
    store.collection('categories').get(),
  ]);
  const categoryNames = Object.fromEntries(categories.docs.map(d => [d.id, d.data().name]));
  const catalog = stock.docs.filter(d => d.data().expiryAt?.toMillis() > Date.now() && d.data().quantityOnHand > d.data().quantityReserved)
    .map(d => { const p = d.data(); return {id: d.id, name: p.productName, category: categoryNames[p.categoryId] || p.categoryId,
      priceCents: p.promotionEnabled && p.promotionPriceCents != null ? p.promotionPriceCents : p.basePriceCents,
      unit: p.unitLabel, available: p.quantityOnHand - p.quantityReserved, expiry: p.expiryAt.toDate().toISOString().slice(0, 10), promotion: !!p.promotionEnabled}; });
  const lines = [];
  for (const order of orders.docs) {
    if (order.data().paymentStatus !== 'paid' || ['cancelled', 'refunded'].includes(order.data().status)) continue;
    const items = await order.ref.collection('items').limit(100).get();
    lines.push(...items.docs.map(d => ({productName: d.data().productName, quantity: d.data().quantity})));
  }
  return {catalog, history: lines};
}
exports.shoppingAssistant = onCall({timeoutSeconds: 120, memory: '512MiB', maxInstances: 3, secrets: [geminiApiKey]}, async request => {
  const store = storeFor(request);
  if ((await store.get()).data()?.status !== 'active') throw new HttpsError('not-found', 'This store is unavailable.');
  const input = normalizeAssistantRequest(request.data);
  // Server-owned quota: 20 requests per account per hour across stores.
  const quota = db.collection('assistantUsage').doc(request.auth.uid);
  await db.runTransaction(async tx => {
    const current = (await tx.get(quota)).data();
    const hour = Math.floor(Date.now() / 3600000);
    const count = current?.hour === hour ? current.count : 0;
    if (count >= 20) throw new HttpsError('resource-exhausted', 'Please try again in the next hour.');
    tx.set(quota, {hour, count: count + 1});
  });
  const context = await assistantContext(store, request.auth.uid);
  const picks = recommendations(context.catalog, context.history);
  const reply = await assistantReply({request: input, context, picks, generate: options => {
    const ai = new GoogleGenAI({apiKey: geminiApiKey.value(), httpOptions: {timeout: 90000}});
    return ai.models.generateContent({model: process.env.SHOPPING_AI_MODEL || 'gemini-3.5-flash-lite', ...options});
  }});
  return {...reply, hasHistory: context.history.length > 0, recommendations: picks.map(p => ({...context.catalog.find(c => c.id === p.id), reason: p.reason}))};
});
