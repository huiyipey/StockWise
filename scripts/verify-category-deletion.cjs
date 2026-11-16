// Disposable .invalid users and isolated test shops only. No real email/push.
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
const storeId = `category_delete_test_${run}`, otherId = `${storeId}_other`;
const app = initializeApp({projectId: project, credential: {/* Provide the authenticated token to this Firebase client. */ getAccessToken: async () => ({access_token: await token(), expires_in: 3500})}}, `category-${run}`);
const auth = getAuth(app), client = new OAuth2Client();
const db = new Firestore({projectId: project, preferRest: true, auth: new GoogleAuth({authClient: client})});
const users = [], result = {passed: false, checks: []};
const base = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;
// Create or sign in the disposable test account.
async function account(label) {
  const email = `stockwise-category-${run}-${label}@example.invalid`, password = randomUUID() + 'Aa9!';
  const record = await auth.createUser({email, password, emailVerified: true});
  const user = {uid: record.uid, email}; users.push(user);
  const response = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`, {
    method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({email, password, returnSecureToken: true}),
  });
  assert.equal(response.status, 200, 'Temporary verified sign-in');
  user.idToken = (await response.json()).idToken;
  return user;
}
// Send a test HTTP request and read its response.
async function request(url, user, method, body) {
  const response = await fetch(url, {method, headers: {'Content-Type': 'application/json', ...(user ? {Authorization: `Bearer ${user.idToken}`} : {})}, ...(body ? {body: JSON.stringify(body)} : {})});
  const text = await response.text();
  let data; try { data = text ? JSON.parse(text) : {}; } catch { data = {nonJson: true}; }
  return {status: response.status, body: data};
}
// Remove the disposable record created by this test.
const remove = (user, categoryId, shop = storeId) => request(`https://asia-southeast1-${project}.cloudfunctions.net/deleteCategory`, user, 'POST', {data: {storeId: shop, categoryId}});
// Encode or read the Firestore value used by the test.
function value(input) {
  if (typeof input === 'string') return {stringValue: input};
  if (typeof input === 'boolean') return {booleanValue: input};
  if (typeof input === 'number') return {integerValue: String(input)};
  if (input instanceof Date) return {timestampValue: input.toISOString()};
  throw Error('Unsupported fixture field');
}
// Apply the test document update using the selected account.
const patch = (user, document, fields) => request(`${base}/${document}`, user, 'PATCH', {fields: Object.fromEntries(Object.entries(fields).map(([key, val]) => [key, value(val)]))});
// Check the expected HTTP result and report a useful failure.
async function expectStatus(promise, status, label) {
  const reply = await promise;
  assert.equal(reply.status, status, `${label}: ${JSON.stringify(reply.body)}`);
  return reply;
}
// Create the temporary category used by this test case.
async function category(id, isActive = true, shop = storeId) {
  await db.doc(`stores/${shop}/categories/${id}`).set({storeId: shop, name: `Temporary ${id}`, isActive, sortOrder: 0});
}
// Create the shop membership used by this test case.
async function member(user, role = 'admin', active = true, shop = storeId) {
  await db.doc(`stores/${shop}/members/${user.uid}`).set({storeId: shop, userId: user.uid, role, isActive: active});
}
(async () => {
  client.setCredentials({access_token: await token(), expiry_date: Date.now() + 3500000});
  let orderCreated = false;
  // Run this operation and handle any reported failure.
  try {
    const admin = await account('admin'), customer = await account('customer'), outsider = await account('outsider');
    for (const id of [storeId, otherId]) await db.doc(`stores/${id}`).set({name: 'Temporary category deletion verification', status: 'category_delete_test', ownerUid: admin.uid});
    await member(admin); await member(customer, 'customer'); await member(outsider, 'admin', true, otherId);
    await category('authorization');
    await expectStatus(remove(null, 'authorization'), 401, 'Unauthenticated');
    await expectStatus(remove(customer, 'authorization'), 403, 'Customer');
    await expectStatus(remove(outsider, 'authorization'), 403, 'Another shop admin');
    await member(outsider, 'admin', false);
    await expectStatus(remove(outsider, 'authorization'), 403, 'Inactive admin');
    assert.equal((await db.doc(`stores/${storeId}/categories/authorization`).get()).exists, true);
    result.checks.push('Customers, unauthenticated, inactive and other-shop admins cannot delete categories');
    for (const role of ['admin', 'owner', 'staff', 'manager']) {
      await member(admin, role);
      await category(`unused-${role}`, role !== 'staff');
      await expectStatus(remove(admin, `unused-${role}`), 200, `Unused ${role}`);
      assert.equal((await db.doc(`stores/${storeId}/categories/unused-${role}`).get()).exists, false);
      await expectStatus(remove(admin, `unused-${role}`), 200, 'Idempotent repeat');
    }
    await member(admin);
    result.checks.push('All same-shop admin aliases can delete unused active/archived categories, with safe repeat requests');
    for (const collection of ['inventoryBatches', 'products', 'inventoryArchive', 'inventoryEvents']) {
      const id = `used-${collection}`;
      await category(id);
      await db.doc(`stores/${storeId}/${collection}/history-test`).set({categoryId: id, productName: 'Temporary history', quantityOnHand: 0});
      const response = await expectStatus(remove(admin, id), 400, collection);
      assert.equal(response.body.error.details.reason, 'category-in-use');
      assert.equal((await db.doc(`stores/${storeId}/categories/${id}`).get()).exists, true);
    }
    result.checks.push('Inventory, saved products, archived inventory and stock events individually protect categories');
    await category('legacy-order');
    await db.doc(`stores/${storeId}/orders/legacy`).set({userId: customer.uid, orderNumber: 'TEST-CATEGORY-ONLY', status: 'cancelled'});
    orderCreated = true;
    await db.doc(`stores/${storeId}/orders/legacy/items/old`).set({categoryId: 'legacy-order', productName: 'Past item'});
    await expectStatus(remove(admin, 'legacy-order'), 400, 'Legacy order history without events/storeId');
    result.checks.push('Past order items protect their category even without current stock, events or a storeId snapshot');
    await category('others');
    await db.doc(`stores/${storeId}/inventoryEvents/missing-category`).set({productName: 'Legacy implicit Others'});
    await expectStatus(remove(admin, 'others'), 400, 'Legacy implicit Others usage');
    await db.doc(`stores/${storeId}/inventoryEvents/missing-category`).delete();
    await expectStatus(remove(admin, 'others'), 200, 'Unused Others with only explicitly categorized history');
    result.checks.push('Legacy rows with no category protect Others, while a truly unused Others can be deleted');
    await category('foreign-only'); await category('foreign-only', true, otherId);
    await db.doc(`stores/${otherId}/products/foreign`).set({categoryId: 'foreign-only'});
    await expectStatus(remove(admin, 'foreign-only'), 200, 'Other-shop usage does not block');
    assert.equal((await db.doc(`stores/${otherId}/categories/foreign-only`).get()).exists, true);
    await expectStatus(request(`${base}/stores/${storeId}/categories/authorization`, admin, 'DELETE'), 403, 'Direct delete bypass');
    result.checks.push('Deletion is isolated to the selected shop; direct client deletion cannot bypass usage checks');
    await category('stale'); await expectStatus(remove(admin, 'stale'), 200, 'Prepare stale editor');
    await expectStatus(patch(admin, `stores/${storeId}/products/stale`, {storeId, categoryId: 'stale', name: 'Stale product'}), 403, 'Stale product category');
    await expectStatus(patch(admin, `stores/${storeId}/inventoryBatches/stale`, {storeId, categoryId: 'stale', productName: 'Stale stock', quantityOnHand: 1, basePriceCents: 100}), 403, 'Stale stock category');
    await expectStatus(patch(admin, `stores/${storeId}/inventoryEvents/stale`, {storeId, categoryId: 'stale', eventType: 'received'}), 403, 'Stale history category');
    await category('valid');
    await expectStatus(patch(admin, `stores/${storeId}/products/valid`, {storeId, categoryId: 'valid', name: 'Valid product'}), 200, 'Valid product');
    await expectStatus(patch(admin, `stores/${storeId}/inventoryBatches/valid`, {storeId, categoryId: 'valid', productName: 'Valid stock', quantityOnHand: 1, basePriceCents: 100, expiryAt: new Date('2099-01-01')}), 200, 'Valid stock');
    await expectStatus(patch(admin, `stores/${storeId}/inventoryEvents/valid`, {storeId, categoryId: 'valid', eventType: 'received'}), 200, 'Valid history');
    result.checks.push('Stale editors cannot create references to deleted categories; valid stock/product/history writes still work');
    for (let i = 0; i < 4; i++) {
      const id = `race-${i}`; await category(id);
      const [deletion, creation] = await Promise.all([remove(admin, id), patch(admin, `stores/${storeId}/products/${id}`, {storeId, categoryId: id, name: 'Concurrent product'})]);
      assert.ok([200, 400].includes(deletion.status), 'Delete race must succeed or detect usage');
      assert.ok([200, 403].includes(creation.status), 'Write race must succeed or reject the stale category');
      const [savedCategory, savedProduct] = await Promise.all([db.doc(`stores/${storeId}/categories/${id}`).get(), db.doc(`stores/${storeId}/products/${id}`).get()]);
      assert.ok(savedCategory.exists || !savedProduct.exists, 'Concurrent writes must not leave a product with a deleted category');
    }
    result.checks.push('Concurrent product creation/category deletion never leaves a dangling category reference');
    const deadline = Date.now() + 60000;
    while ((await db.doc(`stores/${storeId}/orderEmails/legacy`).get()).data()?.status !== 'skipped' && Date.now() < deadline) await new Promise(resolve => setTimeout(resolve, 1000));
    assert.equal((await db.doc(`stores/${storeId}/orderEmails/legacy`).get()).data()?.status, 'skipped');
    result.noEmailOrPushSent = true;
    result.passed = true;
  // Clean up temporary test resources.
  } finally {
    if (orderCreated && !result.passed) {
      // Allow the async .invalid-recipient handler to finish before removing it.
      const deadline = Date.now() + 30000;
      while ((await db.doc(`stores/${storeId}/orderEmails/legacy`).get()).data()?.status !== 'skipped' && Date.now() < deadline) await new Promise(resolve => setTimeout(resolve, 1000));
    }
    for (const id of [storeId, otherId]) { assert.ok(id.startsWith('category_delete_test_')); await db.recursiveDelete(db.doc(`stores/${id}`)); }
    for (const user of users) { assert.ok(user.email.endsWith('@example.invalid')); await db.recursiveDelete(db.doc(`users/${user.uid}`)); await auth.deleteUser(user.uid); }
    result.temporaryResourcesRemoved = true;
    const output = path.resolve(__dirname, '../tmp/category-deletion-2026-11-05/live-result.json');
    fs.writeFileSync(output, JSON.stringify(result, null, 2));
    console.log(JSON.stringify(result));
    await db.terminate(); await deleteApp(app);
  }
})().catch(error => {console.error(error.message); process.exitCode = 1;});
