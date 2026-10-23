// Exercises saved barcode lookup and receiving stock in temporary stores only.
const assert = require('node:assert/strict');
const {randomUUID} = require('node:crypto');
const backendRequire = require('node:module').createRequire(require('node:path').join(__dirname, '../functions/package.json'));
const {initializeApp} = backendRequire('firebase-admin/app');
const {getAuth} = backendRequire('firebase-admin/auth');
const {token, project} = require('./cloud-access.cjs');
const apiKey = require('../android/app/google-services.json').client[0].api_key[0].current_key;
initializeApp({projectId: project, credential: {getAccessToken: async () => ({access_token: await token(), expires_in: 3500})}});
const stores = [`barcode_test_${randomUUID()}`, `barcode_test_${randomUUID()}`];
const base = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;
const prefix = `projects/${project}/databases/(default)/documents`;
const barcode = '0012345678905';
let user;
async function request(url, body, access, method = 'POST') {
  const response = await fetch(url, {method, headers: {'Content-Type': 'application/json', ...(access ? {Authorization: `Bearer ${access}`} : {})}, body: body ? JSON.stringify(body) : undefined});
  const text = await response.text();
  return {status: response.status, data: text ? JSON.parse(text) : null};
}
function fields(data) {
  return Object.fromEntries(Object.entries(data).map(([key, value]) => [key,
    value instanceof Date ? {timestampValue: value.toISOString()} :
    value === null ? {nullValue: null} : typeof value === 'boolean' ? {booleanValue: value} :
    typeof value === 'number' ? {integerValue: String(value)} : {stringValue: value}]));
}
async function seed(path, data) {
  const result = await request(`${base}/${path}`, {fields: fields(data)}, await token(), 'PATCH');
  assert.equal(result.status, 200, 'Temporary fixture setup failed');
}
const read = path => request(`${base}/${path}`, null, user.idToken, 'GET');
function write(path, data, transforms = []) {
  return {update: {name: `${prefix}/${path}`, fields: fields(data)}, updateMask: {fieldPaths: Object.keys(data)},
    ...(transforms.length ? {updateTransforms: transforms.map(fieldPath => ({fieldPath, setToServerValue: 'REQUEST_TIME'}))} : {})};
}
async function lookup(store, code) {
  const result = await request(`${base}/stores/${store}:runQuery`, {structuredQuery: {
    from: [{collectionId: 'products'}], where: {fieldFilter: {field: {fieldPath: 'barcode'}, op: 'EQUAL', value: {stringValue: code}}},
  }}, user.idToken);
  assert.equal(result.status, 200, 'Saved barcode query failed');
  return result.data.filter(row => row.document).map(row => row.document);
}
async function receive(store, productId, batchId, productData, expiry, quantity, isNew = false) {
  const product = {storeId: store, ...productData, isActive: true};
  const batch = {storeId: store, productId, productName: product.name, categoryId: product.categoryId,
    barcode: product.barcode, imagePath: product.imagePath, unitLabel: product.unitLabel, basePriceCents: product.basePriceCents,
    expiryAt: expiry, quantityOnHand: quantity, quantityReserved: 0, promotionEnabled: false, promotionPriceCents: null,
    notifyOnExpiry: true, status: 'active', createdBy: user.localId};
  const result = await request(base + ':commit', {writes: [
    write(`stores/${store}/products/${productId}`, product, isNew ? ['updatedAt', 'createdAt'] : ['updatedAt']),
    write(`stores/${store}/inventoryBatches/${batchId}`, batch, ['updatedAt', 'createdAt']),
    write(`stores/${store}/inventoryEvents/${batchId}`, {storeId: store, batchId, productId, productName: product.name,
      categoryId: product.categoryId, eventType: 'received', quantity, quantityDelta: quantity, actorUid: user.localId}, ['occurredAt']),
  ]}, user.idToken);
  assert.equal(result.status, 200, 'Receiving a new batch failed');
}
(async () => {
  try {
    const email = `stockwise-barcode-test-${randomUUID()}@example.invalid`;
    const signup = await request(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`,
      {email, password: randomUUID() + 'Aa9!', returnSecureToken: true});
    assert.equal(signup.status, 200, 'Temporary sign-up failed');
    user = signup.data;
    const [store, otherStore] = stores;
    for (const id of stores) {
      await seed(`stores/${id}`, {name: 'Temporary barcode test', ownerUid: user.localId, status: 'active'});
      await seed(`stores/${id}/members/${user.localId}`, {userId: user.localId, role: 'owner', isActive: true});
    }
    const template = {name: 'Saved milk', barcode, categoryId: 'dairy', unitLabel: 'bottle', basePriceCents: 750,
      imagePath: `stores/${store}/product-images/latest/test.jpg`};
    const createdAt = new Date('2025-01-01T00:00:00Z');
    await seed(`stores/${store}/products/older`, {storeId: store, ...template, name: 'Older milk', updatedAt: new Date('2025-02-01T00:00:00Z'), createdAt});
    await seed(`stores/${store}/products/latest`, {storeId: store, ...template, updatedAt: new Date('2025-03-01T00:00:00Z'), createdAt});
    await seed(`stores/${otherStore}/products/latest`, {storeId: otherStore, ...template, name: 'Different store product', updatedAt: new Date('2025-04-01T00:00:00Z')});
    await seed(`stores/${store}/inventoryBatches/old-batch`, {storeId: store, productId: 'latest', productName: 'Saved milk',
      barcode, expiryAt: new Date('2025-06-01T00:00:00Z'), quantityOnHand: 7, quantityReserved: 2, status: 'active'});
    const original = (await read(`stores/${store}/inventoryBatches/old-batch`)).data;
    const matches = await lookup(store, barcode);
    assert.equal(matches.length, 2);
    assert.ok(matches.every(doc => doc.name.startsWith(`${prefix}/stores/${store}/products/`)), 'Lookup stays in selected store');
    matches.sort((a, b) => b.fields.updatedAt.timestampValue.localeCompare(a.fields.updatedAt.timestampValue));
    assert.ok(matches[0].name.endsWith('/latest'));
    assert.equal(matches[0].fields.barcode.stringValue, barcode);
    assert.equal((await lookup(store, '12345678905')).length, 0, 'Leading zeros remain significant');
    assert.equal((await lookup(store, 'unknown-code')).length, 0);
    const expiry = new Date('2027-04-15T00:00:00Z');
    await receive(store, 'latest', 'new-batch', {...template, basePriceCents: 800}, expiry, 12);
    const saved = (await read(`stores/${store}/inventoryBatches/new-batch`)).data.fields;
    assert.equal(saved.productId.stringValue, 'latest');
    assert.equal(saved.expiryAt.timestampValue, expiry.toISOString().replace('.000Z', 'Z'));
    assert.equal(saved.quantityOnHand.integerValue, '12');
    assert.equal(saved.quantityReserved.integerValue, '0');
    assert.equal(saved.imagePath.stringValue, template.imagePath);
    assert.equal(saved.basePriceCents.integerValue, '800');
    const old = (await read(`stores/${store}/inventoryBatches/old-batch`)).data;
    assert.deepEqual(old.fields, original.fields, 'Earlier batch details are untouched');
    assert.equal(old.updateTime, original.updateTime);
    const product = (await read(`stores/${store}/products/latest`)).data.fields;
    assert.equal(product.createdAt.timestampValue, '2025-01-01T00:00:00Z', 'Reused product creation date is retained');
    assert.equal((await lookup(store, barcode)).length, 2, 'Receiving stock does not create another duplicate product');
    await receive(store, 'manual', 'manual-batch', {...template, name: 'Manual bread', barcode: 'unknown-code', imagePath: null}, new Date('2027-05-01T00:00:00Z'), 3, true);
    assert.equal((await lookup(store, 'unknown-code')).length, 1, 'Manual entry records a new barcode');
    console.log('PASS: live store barcode lookup, duplicate selection, reused product/photo, separate stock/expiry and manual product creation.');
  } finally {
    const access = await token();
    for (const store of stores) {
      assert.ok(store.startsWith('barcode_test_'));
      const paths = ['products/older', 'products/latest', 'products/manual', 'inventoryBatches/old-batch', 'inventoryBatches/new-batch',
        'inventoryBatches/manual-batch', 'inventoryEvents/new-batch', 'inventoryEvents/manual-batch', ...(user ? [`members/${user.localId}`] : []), ''];
      for (const suffix of paths) {
        const path = `stores/${store}${suffix ? '/' + suffix : ''}`;
        const response = await request(`${base}/${path}`, null, access, 'DELETE');
        assert.ok([200, 204, 404].includes(response.status), 'Temporary fixture cleanup failed');
      }
    }
    if (user) {
      assert.ok(user.email.startsWith('stockwise-barcode-test-'));
      await getAuth().deleteUser(user.localId);
    }
    console.log('Temporary barcode accounts, stores, products and batches removed.');
  }
})().catch(error => {console.error(error.message); process.exitCode = 1;});
