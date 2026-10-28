// Uses temporary accounts/stores only; removes all test resources in finally.
const assert = require('node:assert/strict');
const {randomUUID} = require('node:crypto');
const backendRequire = require('node:module').createRequire(require('node:path').join(__dirname, '../functions/package.json'));
const {initializeApp} = backendRequire('firebase-admin/app');
const {getAuth} = backendRequire('firebase-admin/auth');
const {Firestore} = backendRequire('@google-cloud/firestore');
const {GoogleAuth, OAuth2Client} = backendRequire('google-auth-library');
const {token, project} = require('./cloud-access.cjs');
const {storeNameKey} = require('../functions/store_creation');
const config = require('../android/app/google-services.json');
const apiKey = config.client[0].api_key[0].current_key;
initializeApp({projectId: project, credential: {getAccessToken: async () => ({access_token: await token(), expires_in: 3500})}});
const authClient = new OAuth2Client();
const db = new Firestore({projectId: project, preferRest: true, auth: new GoogleAuth({authClient})});
const recovery = process.argv[2] === '--cleanup';
const suffix = recovery ? process.argv[3] : randomUUID().replaceAll('-', '').slice(0, 12);
assert.match(suffix, /^[a-f0-9]{12}$/);
const prefix = `Store creation test ${suffix}`;
const names = ['race', 'legacy', 'other', 'renamed', 'rename race', 'create rename race'].map(name => `${prefix} ${name}`);
const legacyId = `store_creation_test_${suffix}_legacy`;
const directId = `store_creation_test_${suffix}_direct`;
const storeIds = new Set([legacyId, directId]);
const users = [];
async function signup() {
  const response = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`, {
    method: 'POST', headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({email: `stockwise-store-test-${randomUUID()}@example.invalid`, password: randomUUID() + 'Aa9!', returnSecureToken: true}),
  });
  const data = await response.json();
  assert.equal(response.status, 200, data.error?.message);
  users.push(data);
  return data;
}
async function call(data, user, method = 'createStore') {
  const response = await fetch(`https://asia-southeast1-${project}.cloudfunctions.net/${method}`, {
    method: 'POST', headers: {'Content-Type': 'application/json', ...(user ? {Authorization: `Bearer ${user.idToken}`} : {})},
    body: JSON.stringify({data}),
  });
  const result = await response.json();
  if (result.result?.id) storeIds.add(result.result.id);
  return {status: response.status, ...result};
}
async function clientDocument(path, user, fields, mask) {
  const query = mask ? `?updateMask.fieldPaths=${encodeURIComponent(mask)}` : '';
  const response = await fetch(`https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents/${path}${query}`, {
    method: fields ? 'PATCH' : 'GET', headers: {Authorization: `Bearer ${user.idToken}`, 'Content-Type': 'application/json'},
    ...(fields ? {body: JSON.stringify({fields})} : {}),
  });
  return response.status;
}
(async () => {
  authClient.setCredentials({access_token: await token(), expiry_date: Date.now() + 3500000});
  try {
    console.log(`Temporary test run: ${suffix}`);
    if (recovery) {
      const found = await db.collection('stores').select('name', 'ownerUid').get();
      const owners = new Set();
      for (const doc of found.docs) {
        const name = doc.data().name?.toLowerCase().replace(/\s+/g, ' ');
        if (!names.map(n => n.toLowerCase()).includes(name)) continue;
        const owner = await getAuth().getUser(doc.data().ownerUid);
        assert.match(owner.email, /^stockwise-store-test-[a-f0-9-]+@example\.invalid$/);
        storeIds.add(doc.id);
        owners.add(owner.uid);
      }
      for (const localId of owners) users.push({localId});
      return;
    }
    const [a, b] = await Promise.all([signup(), signup()]);
    for (const user of users) await db.collection('users').doc(user.localId).set({displayName: 'Temporary store tester', retainedSetting: 'preserve'});
    assert.equal((await call({name: names[0], shopAddress: '12 Test Street'})).status, 401);
    for (const input of [{name: names[0]}, {name: names[0], shopAddress: ' \n\t '},
      {name: 'x'.repeat(81), shopAddress: 'Test address'}, {name: names[0], shopAddress: 'x'.repeat(501)}]) {
      assert.equal((await call(input, a)).status, 400);
    }
    console.log('PASS: authentication, required address and input limits.');

    const inputs = [
      {name: names[0], shopAddress: ' 12 Test Street\nTest City 50000 ', ownerUid: b.localId},
      {name: `  ${names[0].toUpperCase().replaceAll(' ', '   ')}  `, shopAddress: '34 Other Test Street', ownerUid: a.localId},
    ];
    const responses = await Promise.all([call(inputs[0], a), call(inputs[1], b)]);
    assert.deepEqual(responses.map(r => r.status).sort(), [200, 409], JSON.stringify(responses));
    const winnerIndex = responses.findIndex(r => r.status === 200);
    const winner = [a, b][winnerIndex];
    const created = responses[winnerIndex].result;
    const store = db.collection('stores').doc(created.id);
    const record = (await store.get()).data();
    assert.equal(record.ownerUid, winner.localId);
    assert.equal(record.shopAddress, inputs[winnerIndex].shopAddress.trim());
    assert.equal(created.shopAddress, record.shopAddress);
    assert.equal((await db.collection('stores').where('nameKey', '==', storeNameKey(names[0])).get()).size, 1);
    assert.equal((await db.collection('storeNames').doc(storeNameKey(names[0])).get()).data().storeId, store.id);
    assert.equal((await store.collection('members').doc(winner.localId).get()).data().role, 'owner');
    assert.equal((await store.collection('categories').get()).size, 7);
    assert.equal((await store.collection('settings').doc('commerce').get()).data().deliveryFeeCents, 500);
    assert.deepEqual((await store.collection('settings').doc('inventory').get()).data().expiryWarningDays, [2, 3, 7]);
    const profile = (await db.collection('users').doc(winner.localId).get()).data();
    assert.equal(profile.retainedSetting, 'preserve');
    assert.equal(profile.activeStoreId, store.id);
    for (const name of [names[0].toUpperCase(), names[0].replaceAll(' ', '\t '), names[0].replace('Store', 'Ｓｔｏｒｅ')]) {
      assert.equal((await call({name, shopAddress: 'Another test address'}, a)).status, 409);
    }
    console.log('PASS: simultaneous duplicate requests create exactly one store; owner, address, defaults and profile retained.');

    const legacy = db.collection('stores').doc(legacyId);
    await legacy.set({name: names[1].replaceAll(' ', '   '), ownerUid: a.localId, status: 'inactive', testRun: suffix});
    await legacy.collection('members').doc(a.localId).set({userId: a.localId, storeId: legacyId, role: 'owner', isActive: true});
    const before = await legacy.get();
    assert.equal((await call({name: names[1].toUpperCase(), shopAddress: 'Legacy test address'}, b)).status, 409);
    assert.equal((await legacy.get()).updateTime.toMillis(), before.updateTime.toMillis());
    assert.equal((await db.collection('storeNames').doc(storeNameKey(names[1])).get()).exists, false);
    console.log('PASS: existing legacy and inactive names rejected without changing existing stores.');

    const attempted = {name: {stringValue: `${prefix} direct`}, ownerUid: {stringValue: a.localId}, status: {stringValue: 'active'}};
    assert.equal(await clientDocument(`stores/${directId}`, a, attempted), 403);
    assert.equal(await clientDocument(`stores/${directId}`, a, {...attempted, shopAddress: {stringValue: 'Direct test address'}}), 403);
    const registry = `storeNames/${storeNameKey(names[0])}`;
    assert.equal(await clientDocument(registry, winner), 403);
    assert.equal(await clientDocument(registry, winner, {storeId: {stringValue: 'spoof'}}), 403);
    assert.equal(await clientDocument(`stores/${store.id}`, winner, {name: {stringValue: names[2]}}, 'name'), 403);
    assert.equal(await clientDocument(`stores/${store.id}`, winner, {shopAddress: {stringValue: ' \n\t '}}, 'shopAddress'), 403);
    assert.equal(await clientDocument(`stores/${store.id}`, winner, {shopAddress: {nullValue: null}}, 'shopAddress'), 403);
    assert.equal(await clientDocument(`stores/${store.id}`, winner, {shopAddress: {stringValue: '56 Test Road\nTest City 50000'}}, 'shopAddress'), 403);
    assert.equal(await clientDocument(`stores/${legacyId}`, a, {status: {stringValue: 'active'}}, 'status'), 200);
    const outsider = [a, b][1 - winnerIndex];
    const otherCreated = await call({name: names[2], shopAddress: '78 Different Shop Street'}, outsider);
    assert.equal(otherCreated.status, 200);
    console.log('PASS: live rules prevent direct name/address edits; different names accepted.');

    const change = (input, user = winner) => call({storeId: store.id, name: names[3], shopAddress: '90 Updated Road\nUpdated City 50000', ...input}, user, 'updateStore');
    assert.equal((await change({}, null)).status, 401);
    assert.equal((await change({}, outsider)).status, 403);
    await store.collection('members').doc(outsider.localId).set({userId: outsider.localId, storeId: store.id, role: 'admin', isActive: true});
    assert.equal((await change({ownerUid: outsider.localId, role: 'owner'}, outsider)).status, 403);
    assert.equal((await change({shopAddress: ' \n\t '})).status, 400);
    assert.equal((await change({name: 'x'.repeat(81)})).status, 400);
    assert.equal((await change({storeId: `store_creation_test_${suffix}_missing`})).status, 404);
    assert.equal(await clientDocument(`stores/${store.id}`, outsider, {ownerUid: {stringValue: outsider.localId}}, 'ownerUid'), 403);
    console.log('PASS: shop edits require the actual owner, an active owner membership and valid name/address.');

    const unchangedBefore = (await store.get()).data();
    for (const name of [names[2].toUpperCase(), names[1].replaceAll(' ', '   '), names[2].replace('Store', 'Ｓｔｏｒｅ')]) {
      assert.equal((await change({name})).status, 409);
    }
    assert.deepEqual((await store.get()).data(), unchangedBefore);
    const addressOnly = await change({name: names[0].toUpperCase().replaceAll(' ', '  ')});
    assert.equal(addressOnly.status, 200, JSON.stringify(addressOnly));
    assert.equal(addressOnly.result.code, created.code);
    assert.equal((await db.collection('storeNames').doc(storeNameKey(names[0])).get()).data().storeId, store.id);
    await store.set({logoPath: `test-logo-${suffix}.png`, retainedSetting: 'preserve'}, {merge: true});
    const renamed = await change({name: ` ${names[3]} `});
    assert.equal(renamed.status, 200, JSON.stringify(renamed));
    assert.equal(renamed.result.name, names[3]);
    assert.equal(renamed.result.logoPath, `test-logo-${suffix}.png`);
    assert.equal(renamed.result.code, created.code);
    const renamedData = (await store.get()).data();
    assert.equal(renamedData.ownerUid, winner.localId);
    assert.equal(renamedData.retainedSetting, 'preserve');
    assert.equal(renamedData.createdAt.toMillis(), unchangedBefore.createdAt.toMillis());
    assert.equal((await store.collection('categories').get()).size, 7);
    assert.equal((await store.collection('settings').doc('commerce').get()).data().deliveryFeeCents, 500);
    assert.equal((await db.collection('storeNames').doc(storeNameKey(names[0])).get()).exists, false);
    assert.equal((await db.collection('storeNames').doc(storeNameKey(names[3])).get()).data().storeId, store.id);
    assert.equal((await call({name: names[0], shopAddress: 'Old name reused test address'}, outsider)).status, 200);
    const legacyEdit = await change({storeId: legacyId, name: names[1], shopAddress: 'Legacy address added'}, a);
    assert.equal(legacyEdit.status, 200, JSON.stringify(legacyEdit));
    assert.equal((await legacy.get()).data().shopAddress, 'Legacy address added');
    console.log('PASS: duplicate renames leave records intact, same-name address changes succeed, legacy addresses can be added and renamed shops retain data.');

    const renameRace = await Promise.all([
      change({name: names[4]}),
      change({storeId: otherCreated.result.id, name: names[4].toUpperCase().replaceAll(' ', '   ')}, outsider),
    ]);
    assert.deepEqual(renameRace.map(r => r.status).sort(), [200, 409], JSON.stringify(renameRace));
    assert.equal((await db.collection('stores').where('nameKey', '==', storeNameKey(names[4])).get()).size, 1);
    const createRace = await Promise.all([
      change({name: names[5]}),
      call({name: names[5].toUpperCase(), shopAddress: 'Concurrent creation test address'}, outsider),
    ]);
    assert.deepEqual(createRace.map(r => r.status).sort(), [200, 409], JSON.stringify(createRace));
    assert.equal((await db.collection('stores').where('nameKey', '==', storeNameKey(names[5])).get()).size, 1);
    console.log('PASS: concurrent rename-versus-rename and create-versus-rename reserve each name once.');
  } finally {
    // Recover successful writes even if a callable response was lost.
    for (const name of names) {
      const found = await db.collection('stores').where('nameKey', '==', storeNameKey(name)).get();
      for (const doc of found.docs) storeIds.add(doc.id);
    }
    for (const id of storeIds) {
      const ref = db.collection('stores').doc(id);
      const doc = await ref.get();
      if (doc.exists) {
        assert.ok(doc.data().name.toLowerCase().replace(/\s+/g, ' ').startsWith(prefix.toLowerCase()), 'Only delete stores owned by this test');
        assert.ok(users.some(user => user.localId === doc.data().ownerUid));
        await db.recursiveDelete(ref);
      }
    }
    for (const name of names) await db.collection('storeNames').doc(storeNameKey(name)).delete();
    for (const user of users) {
      await db.collection('users').doc(user.localId).delete();
      await getAuth().deleteUser(user.localId);
    }
    console.log('Temporary stores, name reservations and accounts removed.');
  }
})().catch(error => {console.error(error.message); process.exitCode = 1;});
