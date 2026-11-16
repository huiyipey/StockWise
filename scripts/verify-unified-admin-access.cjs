// Tests deployed rules using disposable verified .invalid accounts/stores only.
// No production accounts, devices, reports or email recipients are used.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {randomUUID} = require('node:crypto');
const backend = require('node:module').createRequire(path.resolve(__dirname, '../functions/package.json'));
const {initializeApp, deleteApp} = backend('firebase-admin/app');
const {getAuth} = backend('firebase-admin/auth');
const {Firestore, Timestamp} = backend('@google-cloud/firestore');
const {GoogleAuth, OAuth2Client} = backend('google-auth-library');
const {token, project} = require('./cloud-access.cjs');
const apiKey = require('../android/app/google-services.json').client[0].api_key[0].current_key;
const run = randomUUID().replaceAll('-', '').slice(0, 16);
// Keep these checks scoped to disposable test records.
const stores = [`admin_role_test_${run}`, `admin_role_test_other_${run}`];
const app = initializeApp({projectId: project, credential: {/* Provide the authenticated token to this Firebase client. */ getAccessToken: async () => ({access_token: await token(), expires_in: 3500})}}, `admin-role-${run}`);
const auth = getAuth(app), client = new OAuth2Client();
const db = new Firestore({projectId: project, preferRest: true, auth: new GoogleAuth({authClient: client})});
const users = [], objects = [], results = {passed: false, checks: [], roleCases: []};
const base = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;
const prefix = `projects/${project}/databases/(default)/documents`;
const bucket = `${project}.firebasestorage.app`;
const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aWQAAAABJRU5ErkJggg==', 'base64');
// Encode or read the Firestore value used by the test.
function value(data) {
  if (data === null) return {nullValue: null};
  if (typeof data === 'string') return {stringValue: data};
  if (typeof data === 'boolean') return {booleanValue: data};
  if (typeof data === 'number') return {integerValue: String(data)};
  if (data instanceof Date) return {timestampValue: data.toISOString()};
  if (Array.isArray(data)) return {arrayValue: {values: data.map(value)}};
  return {mapValue: {fields: Object.fromEntries(Object.entries(data).map(([key, item]) => [key, value(item)]))}};
}
// Encode the test values as Firestore REST fields.
const fields = data => Object.fromEntries(Object.entries(data).map(([key, item]) => [key, value(item)]));
// Send a test HTTP request and read its response.
async function request(url, user, method = 'GET', body) {
  const response = await fetch(url, {method, headers: {'Content-Type': 'application/json', ...(user ? {Authorization: `Bearer ${user.idToken}`} : {})}, ...(body ? {body: JSON.stringify(body)} : {})});
  const text = await response.text();
  let parsed;
  // Run this operation and handle any reported failure.
  try { parsed = text ? JSON.parse(text) : null; } catch (_) { parsed = {nonJsonResponse: text.slice(0, 500)}; }
  return {status: response.status, body: parsed};
}
// Apply the test document update using the selected account.
async function patch(user, document, data) {
  const url = new URL(`${base}/${document}`);
  for (const key of Object.keys(data)) url.searchParams.append('updateMask.fieldPaths', key);
  return request(url, user, 'PATCH', {fields: fields(data)});
}
// Read the disposable document using the supplied test account.
const read = (user, document) => request(`${base}/${document}`, user);
// Check that the response matches the expected access result.
async function expected(promise, status, label) {
  const response = await promise;
  assert.equal(response.status, status, `${label}: ${JSON.stringify(response.body)}`);
}
// Write the disposable document using the supplied test account.
const write = (document, data, transforms = []) => ({update: {name: `${prefix}/${document}`, fields: fields(data)}, updateMask: {fieldPaths: Object.keys(data)}, ...(transforms.length ? {updateTransforms: transforms.map(fieldPath => ({fieldPath, setToServerValue: 'REQUEST_TIME'}))} : {})});
// Submit the grouped Firestore test writes.
const commit = (user, writes) => request(`${base}:commit`, user, 'POST', {writes});
// Create the disposable account used by this test case.
async function newUser(label) {
  const email = `stockwise-role-${run}-${label}@example.invalid`, password = `${randomUUID()}Aa9!`;
  const record = await auth.createUser({email, password, emailVerified: true});
  const user = {uid: record.uid, email, name: `Temporary ${label}`};
  users.push(user);
  const response = await request(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`, null, 'POST', {email, password, returnSecureToken: true});
  assert.equal(response.status, 200, 'Temporary verified sign-in failed');
  user.idToken = response.body.idToken;
  await db.doc(`users/${user.uid}`).set({displayName: user.name, preferences: {orderUpdates: false, promotions: false, expiryAlerts: false}});
  return user;
}
// Assign the role used by this isolated shop-access scenario.
async function setMember(storeId, user, role, isActive = true) {
  await db.doc(`stores/${storeId}/members/${user.uid}`).set({storeId, userId: user.uid, email: user.email, role, isActive});
}
// Upload the small test image using this account.
async function upload(user, object) {
  const start = await fetch(`https://firebasestorage.googleapis.com/v0/b/${bucket}/o?name=${encodeURIComponent(object)}`, {method: 'POST', headers: {Authorization: `Firebase ${user.idToken}`, 'Content-Type': 'application/json', 'X-Goog-Upload-Protocol': 'resumable', 'X-Goog-Upload-Command': 'start', 'X-Goog-Upload-Header-Content-Length': String(png.length), 'X-Goog-Upload-Header-Content-Type': 'image/png'}, body: JSON.stringify({name: object, contentType: 'image/png'})});
  if (!start.ok) return {status: start.status};
  const session = start.headers.get('x-goog-upload-url');
  assert.ok(session, 'Storage upload session missing');
  const done = await fetch(session, {method: 'POST', headers: {'Content-Type': 'application/octet-stream', 'X-Goog-Upload-Command': 'upload, finalize', 'X-Goog-Upload-Offset': '0'}, body: png});
  if (done.ok) objects.push(object);
  return {status: done.status};
}
// Invoke the callable and check its structured response.
async function callable(user, name, data) {
  return request(`https://asia-southeast1-${project}.cloudfunctions.net/${name}`, user, 'POST', {data});
}
// Create the pending invitation used by this test.
async function invitation(storeId, user, suffix = '') {
  const id = user.email + suffix;
  await db.doc(`stores/${storeId}/adminInvites/${id}`).set({storeId, role: 'admin', emailLowercase: user.email, status: 'pending'});
  return id;
}
// Build the atomic invitation acceptance and membership writes.
function acceptWrites(storeId, user, inviteId) {
  return [write(`stores/${storeId}/members/${user.uid}`, {storeId, userId: user.uid, email: user.email, role: 'admin', isActive: true, invitationId: inviteId}, ['joinedAt', 'updatedAt']),
    write(`stores/${storeId}/adminInvites/${inviteId}`, {status: 'accepted', acceptedBy: user.uid}, ['acceptedAt', 'updatedAt'])];
}
(async () => {
  client.setCredentials({access_token: await token(), expiry_date: Date.now() + 3500000});
  try {
    const admin = await newUser('admin'), peer = await newUser('peer'), customer = await newUser('customer'), foreign = await newUser('foreign'), invited = await newUser('invited');
    const [storeId, otherId] = stores, store = `stores/${storeId}`;
    // A non-active test status keeps schedulers away; customer chat fixture below is pre-created.
    await db.doc(store).set({name: 'Temporary unified role verification', status: 'admin_role_test', ownerUid: customer.uid});
    await db.doc(`stores/${otherId}`).set({name: 'Temporary other shop', status: 'admin_role_test', ownerUid: foreign.uid});
    await setMember(storeId, peer, 'admin');
    await setMember(storeId, customer, 'customer');
    await setMember(otherId, foreign, 'admin');
    await db.doc(`${store}/inventoryArchive/old`).set({productName: 'Archived test'});
    await db.doc(`${store}/reportDeliveries/test`).set({status: 'test_only'});
    // .invalid recipients are explicitly skipped by the deployed order email handler.
    await db.doc(`${store}/orders/test`).set({userId: customer.uid, orderNumber: 'TEST-ONLY', status: 'to_pay'});
    await db.doc(`${store}/orders/test/items/test`).set({productName: 'Temporary item', quantity: 1});
    await db.doc(`${store}/conversations/${customer.uid}`).set({storeId, customerId: customer.uid, customerName: customer.name, lastMessageId: 'initial', lastMessage: 'Test only', lastMessageAt: Timestamp.now(), lastSenderId: customer.uid, lastSenderRole: 'customer', customerReadAt: null, adminReadAt: null});
    for (const role of ['admin', 'owner', 'manager', 'staff']) {
      await setMember(storeId, admin, role);
      await expected(patch(admin, store, {testAdminPreference: role}), 200, `${role} store settings`);
      await expected(read(admin, `${store}/members/${peer.uid}`), 200, `${role} team access`);
      await expected(request(`${base}/${store}/members`, admin), 200, `${role} team listing`);
      await expected(patch(admin, `${store}/categories/test`, {storeId, name: 'Test Category', isActive: true}), 200, `${role} categories`);
      await expected(patch(admin, `${store}/products/test`, {storeId, name: 'Test Product'}), 200, `${role} product create/update`);
      await expected(request(`${base}/${store}/products/test`, admin, 'DELETE'), 200, `${role} product delete`);
      const future = new Date(Date.now() + 86400000 * 60);
      await expected(patch(admin, `${store}/inventoryBatches/test-${role}`, {storeId, productId: 'test', productName: 'Temporary Product', status: 'active', expiryAt: future, quantityOnHand: 3, quantityReserved: 0, basePriceCents: 100, promotionEnabled: false}), 200, `${role} inventory create`);
      await expected(patch(admin, `${store}/inventoryBatches/test-${role}`, {quantityOnHand: 2}), 200, `${role} inventory update`);
      await expected(patch(admin, `${store}/inventoryEvents/test-${role}`, {storeId, eventType: 'adjusted', quantity: 1}), 200, `${role} inventory audit event`);
      for (const document of ['inventoryArchive/old', 'reportDeliveries/test', 'orders/test', 'orders/test/items/test', `conversations/${customer.uid}`]) await expected(read(admin, `${store}/${document}`), 200, `${role} private read ${document}`);
      await expected(request(`${base}/${store}/conversations`, admin), 200, `${role} inbox listing`);
      const messageId = `reply-${role}`;
      await expected(commit(admin, [write(`${store}/conversations/${customer.uid}/messages/${messageId}`, {senderId: admin.uid, senderName: admin.name, senderRole: 'admin', text: 'Temporary administrative reply'}, ['sentAt']), write(`${store}/conversations/${customer.uid}`, {lastMessageId: messageId, lastMessage: 'Temporary administrative reply', lastSenderId: admin.uid, lastSenderRole: 'admin'}, ['lastMessageAt', 'adminReadAt'])]), 200, `${role} inbox reply`);
      await expected(patch(admin, `${store}/settings/inventoryReceiving`, {revision: 1}), 200, `${role} inventory receiving settings`);
      await expected(patch(admin, `${store}/members/${admin.uid}`, {reportsByEmail: true, reportEmailSchedules: {sales: ['daily', 'monthly'], waste: ['weekly']}}), 200, `${role} own report schedules`);
      await expected(upload(admin, `${store}/product-images/test/${role}.png`), 200, `${role} product image upload`);
      await expected(upload(admin, `${store}/order-attachments/test/${role}.png`), 200, `${role} receipt upload`);
      results.roleCases.push({role, passed: true});
    }
    results.checks.push('Canonical Admin and all three legacy roles have inventory, categories, products, settings, orders/receipts, reports/preferences, team and chat access');
    for (const [label, user] of [['customer', customer], ['inactive', admin], ['cross-store admin', foreign]]) {
      if (label === 'inactive') await setMember(storeId, admin, 'admin', false);
      for (const document of ['members/' + peer.uid, 'inventoryArchive/old', 'reportDeliveries/test', `conversations/${customer.uid}`]) {
        // Customers retain read access to their own customer conversation.
        if (label === 'customer' && document.startsWith('conversations/')) continue;
        await expected(read(user, `${store}/${document}`), 403, `${label} private access denied`);
      }
      for (const [document, data] of [['categories/denied', {storeId, name: 'Denied', isActive: true}], ['products/denied', {name: 'Denied'}], ['settings/inventoryReceiving', {revision: 9}], ['members/' + peer.uid, {isActive: false}]]) await expected(patch(user, `${store}/${document}`, data), 403, `${label} ${document} write denied`);
      await expected(upload(user, `${store}/product-images/test/denied-${label.replaceAll(' ', '-')}.png`), 403, `${label} image upload denied`);
    }
    results.checks.push('Customer membership, inactive admin and admin of another shop cannot use administrative reads/writes/uploads; ownerUid alone grants no rights');
    await setMember(storeId, admin, 'admin');
    for (const data of [{role: 'owner'}, {isActive: false}, {userId: peer.uid}, {storeId: otherId}]) await expected(patch(admin, `${store}/members/${admin.uid}`, data), 403, 'Direct own privilege mutation denied');
    await expected(patch(admin, `${store}/members/${peer.uid}`, {isActive: false}), 403, 'Direct peer deactivation denied');
    await expected(request(`${base}/${store}/members/${peer.uid}`, admin, 'DELETE'), 403, 'Direct peer deletion denied');
    await expected(patch(customer, `${store}/members/${customer.uid}`, {role: 'admin', isActive: true}), 403, 'Customer escalation denied');
    await expected(patch(admin, `${store}/members/${peer.uid}`, {reportsByEmail: false}), 403, 'Peer preference rewrite denied');
    await expected(patch(admin, `${store}/adminInvites/forged`, {storeId, role: 'admin', emailLowercase: invited.email, status: 'pending'}), 403, 'Direct invitation bypass denied');
    results.checks.push('Clients cannot bypass the transactional admin-access callable or rewrite another admin’s report preferences');
    const inviteId = await invitation(storeId, invited);
    const accepted = acceptWrites(storeId, invited, inviteId);
    await expected(commit(invited, [accepted[0]]), 403, 'Membership acceptance without consuming invitation denied');
    await expected(commit(invited, [accepted[1]]), 403, 'Consuming invitation without admin membership denied');
    await expected(commit(customer, acceptWrites(storeId, customer, inviteId)), 403, 'Another customer stealing invitation denied');
    await expected(commit(invited, accepted), 200, 'Atomic invitation acceptance');
    assert.equal((await db.doc(`${store}/members/${invited.uid}`).get()).data().role, 'admin');
    const duplicate = await invitation(storeId, admin, '.duplicate');
    await expected(commit(admin, [write(`${store}/adminInvites/${duplicate}`, {status: 'accepted', acceptedBy: admin.uid}, ['acceptedAt', 'updatedAt'])]), 200, 'Existing admin can consume invitation without rewriting membership');
    await setMember(storeId, invited, 'owner', false);
    const reactivate = await invitation(storeId, invited, '.reactivate');
    await expected(commit(invited, acceptWrites(storeId, invited, reactivate)), 200, 'Authorized invitation reactivates legacy member as admin');
    results.checks.push('Only the verified invited email can accept; invitation and membership must change atomically, existing admin preferences remain intact, inactive legacy membership becomes Admin');
    await expected(callable(customer, 'setStoreAdminActive', {storeId, userId: peer.uid, isActive: false}), 403, 'Customer admin-access callable denied');
    await expected(callable(foreign, 'setStoreAdminActive', {storeId, userId: peer.uid, isActive: false}), 403, 'Cross-store admin-access callable denied');
    const self = await callable(admin, 'setStoreAdminActive', {storeId, userId: admin.uid, isActive: false});
    assert.equal(self.status, 400, `Self deactivation must be rejected: ${JSON.stringify(self.body)}`);
    await expected(callable(admin, 'setStoreAdminActive', {storeId, userId: peer.uid, isActive: false}), 200, 'Peer admin deactivation');
    assert.equal((await db.doc(`${store}/members/${peer.uid}`).get()).data().isActive, false);
    await expected(callable(admin, 'setStoreAdminActive', {storeId, userId: peer.uid, isActive: true}), 200, 'Peer admin reactivation');
    results.checks.push('Deployed admin-access callable rejects customer/cross-shop/self deactivation and permits peer disable/restore');
    // Confirm the asynchronous confirmation handler has completed its explicit
    // .invalid-recipient skip before removing the fixture; no SMTP is invoked.
    const deadline = Date.now() + 60000;
    let emailStatus;
    do {
      emailStatus = (await db.doc(`${store}/orderEmails/test`).get()).data()?.status;
      if (emailStatus === 'skipped') break;
      await new Promise(resolve => setTimeout(resolve, 1000));
    } while (Date.now() < deadline);
    assert.equal(emailStatus, 'skipped', 'Temporary order email must be explicitly skipped before cleanup');
    results.checks.push('Temporary order confirmation was explicitly skipped for a .invalid recipient; no email or push was sent');
    results.passed = true;
  // Clean up temporary test resources.
  } finally {
    const access = await token();
    for (const object of objects) {
      assert.ok(stores.some(storeId => object.startsWith(`stores/${storeId}/`)));
      const response = await fetch(`https://storage.googleapis.com/storage/v1/b/${bucket}/o/${encodeURIComponent(object)}`, {method: 'DELETE', headers: {Authorization: `Bearer ${access}`}});
      assert.ok([204, 404].includes(response.status), 'Temporary Storage cleanup failed');
    }
    for (const storeId of stores) {assert.ok(storeId.startsWith('admin_role_test_')); await db.recursiveDelete(db.doc(`stores/${storeId}`));}
    for (const user of users) {assert.ok(user.email.endsWith('@example.invalid')); await db.recursiveDelete(db.doc(`users/${user.uid}`)); await auth.deleteUser(user.uid);}
    results.temporaryResourcesRemoved = true;
    const destination = path.resolve(__dirname, '../tmp/unified-admin-2026-11-04');
    fs.mkdirSync(destination, {recursive: true});
    fs.writeFileSync(path.join(destination, 'live-security-result.json'), JSON.stringify(results, null, 2));
    console.log(JSON.stringify(results));
    await db.terminate(); await deleteApp(app);
  }
})().catch(error => {console.error(error.message); process.exitCode = 1;});
