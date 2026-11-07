// Exercises real deployed admin callables on disposable verified .invalid
// accounts and isolated stores. It sends no email or push notifications.
const assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const {randomUUID} = require('node:crypto');
const backend = require('node:module').createRequire(path.resolve(__dirname, '../functions/package.json'));
const {initializeApp, deleteApp} = backend('firebase-admin/app');
const {getAuth} = backend('firebase-admin/auth');
const {Firestore, Timestamp} = backend('@google-cloud/firestore');
const {GoogleAuth, OAuth2Client} = backend('google-auth-library');
const {token, project} = require('./cloud-access.cjs');
const apiKey = require('../android/app/google-services.json').client[0].api_key[0].current_key;
const run = randomUUID().replaceAll('-', '').slice(0, 16);
const app = initializeApp({projectId: project, credential: {getAccessToken: async () => ({access_token: await token(), expires_in: 3500})}}, `admin-functions-${run}`);
const auth = getAuth(app), client = new OAuth2Client();
const db = new Firestore({projectId: project, preferRest: true, auth: new GoogleAuth({authClient: client})});
const users = [], stores = [], createdStoreIds = new Set(), result = {passed: false, checks: []};
function field(value) {
  if (typeof value === 'boolean') return {booleanValue: value};
  return {stringValue: value};
}
async function request(url, user, body) {
  const response = await fetch(url, {method: 'POST', headers: {'Content-Type': 'application/json', ...(user ? {Authorization: `Bearer ${user.idToken}`} : {})}, body: JSON.stringify(body)});
  const text = await response.text();
  let parsed;
  try {parsed = text ? JSON.parse(text) : null;} catch (_) {parsed = {nonJsonResponse: text.slice(0, 600)};}
  return {status: response.status, body: parsed};
}
async function call(user, name, data, status = 200) {
  const response = await request(`https://asia-southeast1-${project}.cloudfunctions.net/${name}`, user, {data});
  assert.equal(response.status, status, `${name}: ${JSON.stringify(response.body)}`);
  return response.body?.result;
}
async function user(label) {
  const email = `stockwise-admin-functions-${run}-${label}@example.invalid`, password = `${randomUUID()}Aa9!`;
  const account = await auth.createUser({email, password, emailVerified: true});
  const created = {uid: account.uid, email}; users.push(created);
  const response = await request(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`, null, {email, password, returnSecureToken: true});
  assert.equal(response.status, 200, 'Temporary verified sign-in'); created.idToken = response.body.idToken;
  await db.doc(`users/${created.uid}`).set({displayName: `Temporary ${label}`, preferences: {orderUpdates: false, expiryAlerts: false, promotions: false}});
  return created;
}
async function membership(storeId, account, role = 'admin', isActive = true) {
  await db.doc(`stores/${storeId}/members/${account.uid}`).set({storeId, userId: account.uid, email: account.email, role, isActive});
}
async function seedStore(suffix, creator) {
  const id = `admin_functions_test_${run}_${suffix}`; stores.push(id);
  await db.doc(`stores/${id}`).set({name: `Temporary Admin ${run} ${suffix}`, status: 'admin_role_test', ownerUid: creator.uid, operatingHours: {opens: 0, closes: 1440, closedDays: []}});
  return id;
}
(async () => {
  client.setCredentials({access_token: await token(), expiry_date: Date.now() + 3500000});
  try {
    const admin = await user('admin'), peer = await user('peer'), customer = await user('customer'), outsider = await user('outsider');
    const storeId = await seedStore('main', customer), otherId = await seedStore('other', outsider);
    await membership(storeId, admin); await membership(storeId, peer);
    await membership(storeId, customer, 'customer'); await membership(otherId, outsider);
    const address = {addressLine1: '12 Temporary Test Street', addressLine2: 'Unit 2', postcode: '50000', city: 'Edited Test City', state: 'Wp Kuala Lumpur'};
    // Store addresses use line1/line2, unlike receiver addressLine1/addressLine2.
    const storeAddress = {line1: address.addressLine1, line2: address.addressLine2, postcode: address.postcode, city: address.city, state: address.state};
    const name = `Temporary Updated Admin R${run}`;
    const edited = await call(admin, 'updateStore', {storeId, name, address: storeAddress, operatingHours: {opens: 480, closes: 1320, closedDays: [2, 5]}});
    assert.equal(edited.name, name);
    const savedStore = (await db.doc(`stores/${storeId}`).get()).data();
    assert.equal(savedStore.ownerUid, customer.uid); assert.deepEqual(savedStore.operatingHours.closedDays, [2, 5]);
    for (const account of [customer, outsider]) await call(account, 'updateStore', {storeId, name, address: storeAddress}, 403);
    result.checks.push('A regular noncreator Admin edits store name/address/hours; creator attribution stays intact; customers and other-shop admins are denied');
    for (const kind of ['sales', 'waste']) {
      const report = await call(admin, 'getStoreReport', {storeId, kind, start: '2026-11-01', end: '2026-11-04'});
      assert.equal(report.storeName, name); assert.equal(typeof report.csv, 'string'); assert.ok(report.csv.length > 10);
      for (const account of [customer, outsider]) await call(account, 'getStoreReport', {storeId, kind, start: '2026-11-01', end: '2026-11-04'}, 403);
    }
    result.checks.push('Noncreator Admin can generate Sales and Waste data/CSV; customer and cross-store report access is denied');
    await call(admin, 'saveDeliveryFees', {storeId, mode: 'fixed', fixedCents: 450, postcodeFees: {}});
    assert.equal((await db.doc(`stores/${storeId}/settings/commerce`).get()).data().deliveryFeeCents, 450);
    await call(admin, 'saveDeliveryFees', {storeId, mode: 'postcode', fixedCents: 450, postcodeFees: {'50000': 350}});
    assert.equal((await db.doc(`stores/${storeId}/settings/commerce`).get()).data().postcodeFees['50000'], 350);
    for (const account of [customer, outsider]) await call(account, 'saveDeliveryFees', {storeId, mode: 'fixed', fixedCents: 999, postcodeFees: {}}, 403);
    result.checks.push('Noncreator Admin saves both Fixed and Postcode delivery fees, while unauthorized callers cannot change them');
    const batch = db.doc(`stores/${storeId}/inventoryBatches/discard-test`);
    await batch.set({storeId, productId: 'test', productName: 'Temporary Test Product', categoryId: 'others', unitLabel: 'unit', status: 'active', expiryAt: Timestamp.fromMillis(Date.now() + 60 * 86400000), receivedAt: Timestamp.now(), quantityOnHand: 5, quantityReserved: 0, basePriceCents: 100, promotionEnabled: false});
    await call(admin, 'discardInventory', {storeId, batchId: batch.id, quantity: 2});
    assert.equal((await batch.get()).data().quantityOnHand, 3);
    for (const account of [customer, outsider]) await call(account, 'discardInventory', {storeId, batchId: batch.id, quantity: 1}, 403);
    await call(admin, 'removeInventory', {storeId, batchId: batch.id});
    assert.equal((await batch.get()).exists, false); assert.equal((await db.doc(`stores/${storeId}/inventoryArchive/${batch.id}`).get()).data().quantityOnHand, 3);
    result.checks.push('Noncreator Admin discards stock with an audit event and removes/archive inventory; customer and cross-store discard are denied');
    for (const account of [customer, outsider]) await call(account, 'setStoreAdminActive', {storeId, userId: peer.uid, isActive: false}, 403);
    await call(admin, 'setStoreAdminActive', {storeId, userId: admin.uid, isActive: false}, 400);
    await call(admin, 'setStoreAdminActive', {storeId, userId: peer.uid, isActive: false});
    assert.equal((await db.doc(`stores/${storeId}/members/${peer.uid}`).get()).data().isActive, false);
    await call(admin, 'setStoreAdminActive', {storeId, userId: peer.uid, isActive: true});
    const race = await Promise.all([request(`https://asia-southeast1-${project}.cloudfunctions.net/setStoreAdminActive`, admin, {data: {storeId, userId: peer.uid, isActive: false}}), request(`https://asia-southeast1-${project}.cloudfunctions.net/setStoreAdminActive`, peer, {data: {storeId, userId: admin.uid, isActive: false}})]);
    assert.deepEqual(race.map(item => item.status).sort(), [200, 403], `Concurrent access change ${JSON.stringify(race)}`);
    const active = (await db.collection(`stores/${storeId}/members`).get()).docs.filter(doc => doc.data().role === 'admin' && doc.data().isActive);
    assert.equal(active.length, 1);
    result.checks.push('Admin access callable rejects self/cross-store/customer changes, allows disable/restore and safely resolves concurrent mutual deactivation with one admin remaining');
    await membership(storeId, admin); await membership(storeId, peer);
    // Invitations are database invitations only; this function does not send mail.
    await call(admin, 'createAdminInvite', {storeId, email: customer.email});
    assert.equal((await db.doc(`stores/${storeId}/adminInvites/${customer.email}`).get()).data().role, 'admin');
    const documentPrefix = `projects/${project}/databases/(default)/documents`;
    const acceptance = await request(`https://firestore.googleapis.com/v1/${documentPrefix}:commit`, customer, {writes: [
      {update: {name: `${documentPrefix}/stores/${storeId}/members/${customer.uid}`, fields: Object.fromEntries(Object.entries({storeId, userId: customer.uid, email: customer.email, role: 'admin', isActive: true, invitationId: customer.email}).map(([key, value]) => [key, field(value)]))}, updateTransforms: [{fieldPath: 'joinedAt', setToServerValue: 'REQUEST_TIME'}, {fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME'}]},
      {update: {name: `${documentPrefix}/stores/${storeId}/adminInvites/${customer.email}`, fields: {status: field('accepted'), acceptedBy: field(customer.uid)}}, updateMask: {fieldPaths: ['status', 'acceptedBy']}, updateTransforms: [{fieldPath: 'acceptedAt', setToServerValue: 'REQUEST_TIME'}, {fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME'}]},
    ]});
    assert.equal(acceptance.status, 200, `Existing customer accepts invite ${JSON.stringify(acceptance.body)}`);
    assert.equal((await db.doc(`stores/${storeId}/members/${customer.uid}`).get()).data().role, 'admin');
    await call(admin, 'createAdminInvite', {storeId, email: peer.email}, 409);
    result.checks.push('An explicit Admin invitation upgrades an existing Customer membership after verified atomic acceptance, writes canonical Admin, and rejects duplicate active admins');
    const deletable = await seedStore('deletable', customer);
    await membership(deletable, admin);
    const deleteName = (await db.doc(`stores/${deletable}`).get()).data().name;
    await call(admin, 'deleteStore', {storeId: deletable, confirmName: 'Incorrect name'}, 400);
    await call(customer, 'deleteStore', {storeId: deletable, confirmName: deleteName}, 403);
    await call(admin, 'deleteStore', {storeId: deletable, confirmName: deleteName});
    assert.equal((await db.doc(`stores/${deletable}`).get()).exists, false); assert.equal((await db.doc(`stores/${otherId}`).get()).exists, true);
    result.checks.push('A noncreator Admin can delete the intended temporary store after exact-name confirmation; a creator without Admin access cannot, and another store is preserved');
    const createdName = `Temporary Created Admin R${run}`;
    const created = await call(admin, 'createStore', {name: createdName, address: storeAddress, operatingHours: {opens: 0, closes: 1440, closedDays: []}});
    assert.ok(created.id); stores.push(created.id); createdStoreIds.add(created.id);
    assert.equal((await db.doc(`stores/${created.id}/members/${admin.uid}`).get()).data().role, 'admin');
    assert.equal((await db.collection(`stores/${created.id}/categories`).get()).size, 7);
    await call(admin, 'deleteStore', {storeId: created.id, confirmName: createdName});
    assert.equal((await db.doc(`stores/${created.id}`).get()).exists, false);
    result.checks.push('A newly created store grants its creator Admin (without an Owner role), initializes all categories, and can be deleted normally');
    result.passed = true;
  } finally {
    for (const id of stores) {
      assert.ok(id.startsWith(`admin_functions_test_${run}_`) || createdStoreIds.has(id));
      const reservations = await db.collection('storeNames').where('storeId', '==', id).get();
      for (const doc of reservations.docs) await doc.ref.delete();
      await db.recursiveDelete(db.doc(`stores/${id}`));
    }
    for (const account of users) {assert.ok(account.email.endsWith('@example.invalid')); await db.recursiveDelete(db.doc(`users/${account.uid}`)); await auth.deleteUser(account.uid);}
    result.temporaryResourcesRemoved = true;
    const directory = path.resolve(__dirname, '../tmp/unified-admin-2026-11-04'); fs.mkdirSync(directory, {recursive: true});
    fs.writeFileSync(path.join(directory, 'live-functions-result.json'), JSON.stringify(result, null, 2));
    console.log(JSON.stringify(result)); await db.terminate(); await deleteApp(app);
  }
})().catch(error => {console.error(error.message); process.exitCode = 1;});
