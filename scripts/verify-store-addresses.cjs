// Uses only temporary verified accounts and stores; cleans them in finally.
const assert = require('node:assert/strict');
const {randomUUID} = require('node:crypto');
const {createRequire} = require('node:module');
const path = require('node:path');
const backend = createRequire(path.join(__dirname, '../functions/package.json'));
const {initializeApp} = backend('firebase-admin/app');
const {getAuth} = backend('firebase-admin/auth');
const {Firestore} = backend('@google-cloud/firestore');
const {GoogleAuth, OAuth2Client} = backend('google-auth-library');
const {token, project} = require('./cloud-access.cjs');
const {storeNameKey} = require('../functions/store_creation');
const config = require('../android/app/google-services.json');
const apiKey = config.client[0].api_key[0].current_key;
initializeApp({projectId: project, credential: {getAccessToken: async () => ({access_token: await token(), expires_in: 3500})}});
const auth = getAuth();
const authClient = new OAuth2Client();
const db = new Firestore({projectId: project, preferRest: true, auth: new GoogleAuth({authClient})});
const run = randomUUID().replaceAll('-', '').slice(0, 12);
const prefix = `Store address test ${run}`;
const names = [prefix, `${prefix} renamed`, `${prefix} legacy`];
const users = [];
const storeIds = new Set();
async function account(index) {
  const password = randomUUID() + 'Aa9!';
  const email = `stockwise-store-address-${run}-${index}@example.invalid`;
  const user = await auth.createUser({email, password, emailVerified: true});
  users.push(user);
  const response = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`, {
    method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({email, password, returnSecureToken: true}),
  });
  const data = await response.json();
  assert.equal(response.status, 200, data.error?.message);
  return {uid: user.uid, idToken: data.idToken};
}
async function call(method, data, user) {
  const response = await fetch(`https://asia-southeast1-${project}.cloudfunctions.net/${method}`, {
    method: 'POST', headers: {'Content-Type': 'application/json', ...(user ? {Authorization: `Bearer ${user.idToken}`} : {})},
    body: JSON.stringify({data}),
  });
  const body = await response.json();
  if (body.result?.id) storeIds.add(body.result.id);
  return {status: response.status, ...body};
}
async function patchAddress(storeId, user) {
  const response = await fetch(`https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents/stores/${storeId}?updateMask.fieldPaths=address`, {
    method: 'PATCH', headers: {Authorization: `Bearer ${user.idToken}`, 'Content-Type': 'application/json'},
    body: JSON.stringify({fields: {address: {mapValue: {fields: {state: {stringValue: 'Spoofed'}}}}}}),
  });
  return response.status;
}
(async () => {
  authClient.setCredentials({access_token: await token(), expiry_date: Date.now() + 3500000});
  try {
    console.log(`Temporary address test run: ${run}`);
    const owner = await account(0);
    const other = await account(1);
    const address = {line1: ' 12 Jalan SS15/4 ', line2: ' SS15 ', postcode: '47500', city: ' Bandar Sunway ', state: 'Spoofed'};
    assert.equal((await call('createStore', {name: names[0], address})).status, 401);
    for (const invalid of [{...address, postcode: '99999'}, {...address, city: ' '}, {...address, line1: ' '}]) {
      assert.equal((await call('createStore', {name: names[0], address: invalid}, owner)).status, 400);
    }
    const created = await call('createStore', {name: names[0], address}, owner);
    assert.equal(created.status, 200, JSON.stringify(created));
    const ref = db.collection('stores').doc(created.result.id);
    let record = (await ref.get()).data();
    assert.deepEqual(record.address, {line1: '12 Jalan SS15/4', line2: 'SS15', postcode: '47500', city: 'Bandar Sunway', state: 'Selangor'});
    assert.deepEqual(created.result.address, record.address);
    assert.equal(record.shopAddress, '12 Jalan SS15/4\nSS15\n47500 Bandar Sunway, Selangor');
    assert.equal((await ref.collection('members').doc(owner.uid).get()).data().role, 'owner');
    console.log('PASS: verified account creates a structured address; City edits are retained and State is derived on the server.');
    const edit = {storeId: ref.id, name: names[1], address: {...address, line2: '', postcode: '01000', city: 'Custom Kangar', state: 'Wrong'}};
    assert.equal((await call('updateStore', edit, other)).status, 403);
    assert.equal(await patchAddress(ref.id, owner), 403);
    const before = (await ref.get()).data();
    assert.equal((await call('updateStore', {...edit, address: {...address, postcode: '99999'}}, owner)).status, 400);
    assert.deepEqual((await ref.get()).data(), before);
    const updated = await call('updateStore', edit, owner);
    assert.equal(updated.status, 200, JSON.stringify(updated));
    record = (await ref.get()).data();
    assert.deepEqual(updated.result.address, record.address);
    assert.equal(record.address.postcode, '01000');
    assert.equal(record.address.city, 'Custom Kangar');
    assert.equal(record.address.state, 'Perlis');
    assert.equal(record.shopAddress, '12 Jalan SS15/4\n01000 Custom Kangar, Perlis');
    assert.equal(record.code, created.result.code);
    assert.equal(record.ownerUid, owner.uid);
    console.log('PASS: structured edits persist, omit empty Address 2, preserve store identity and reject direct or unauthorized edits.');
    const legacy = await call('createStore', {name: names[2], shopAddress: '12 Existing Road\n50000 Kuala Lumpur'}, owner);
    assert.equal(legacy.status, 200, JSON.stringify(legacy));
    const migrated = await call('updateStore', {storeId: legacy.result.id, name: names[2], address}, owner);
    assert.equal(migrated.status, 200, JSON.stringify(migrated));
    assert.equal((await db.collection('stores').doc(legacy.result.id).get()).data().address.state, 'Selangor');
    console.log('PASS: older clients still work and legacy shops can confirm a structured address.');
  } finally {
    for (const name of names) {
      const found = await db.collection('stores').where('nameKey', '==', storeNameKey(name)).get();
      for (const doc of found.docs) storeIds.add(doc.id);
    }
    for (const id of storeIds) {
      const ref = db.collection('stores').doc(id);
      const snapshot = await ref.get();
      if (!snapshot.exists) continue;
      assert.ok(snapshot.data().name.startsWith(prefix));
      assert.ok(users.some(user => user.uid === snapshot.data().ownerUid));
      await db.recursiveDelete(ref);
    }
    for (const name of names) {
      const ref = db.collection('storeNames').doc(storeNameKey(name));
      const snapshot = await ref.get();
      if (snapshot.exists) assert.ok(storeIds.has(snapshot.data().storeId));
      await ref.delete();
    }
    for (const user of users) {
      assert.ok(user.email.startsWith(`stockwise-store-address-${run}-`));
      await db.collection('users').doc(user.uid).delete();
      await auth.deleteUser(user.uid);
    }
    console.log('Temporary stores, reservations and accounts removed.');
  }
})().catch(error => {console.error(error.message); process.exitCode = 1;});
