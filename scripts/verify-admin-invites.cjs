// Uses temporary accounts/store only; does not send email and cleans up all test resources.
const assert = require('node:assert/strict');
const {randomUUID} = require('node:crypto');
const backendRequire = require('node:module').createRequire(require('node:path').join(__dirname, '../functions/package.json'));
const {initializeApp} = backendRequire('firebase-admin/app');
const {Firestore} = backendRequire('@google-cloud/firestore');
const {GoogleAuth, OAuth2Client} = backendRequire('google-auth-library');
const {getAuth} = backendRequire('firebase-admin/auth');
const {token, project} = require('./cloud-access.cjs');
const apiKey = require('../android/app/google-services.json').client[0].api_key[0].current_key;
initializeApp({projectId: project, credential: {getAccessToken: async () => ({access_token: await token(), expires_in: 3500})}});
const client = new OAuth2Client();
const db = new Firestore({projectId: project, preferRest: true, auth: new GoogleAuth({authClient: client})});
const storeId = `invite_test_${randomUUID().replaceAll('-', '').slice(0, 16)}`;
const users = [];
async function signUp() {
  const email = `stockwise-invite-test-${randomUUID()}@example.invalid`;
  const response = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`, {
    method: 'POST', headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({email, password: randomUUID() + 'Aa9!', returnSecureToken: true}),
  });
  const data = await response.json();
  if (!response.ok) throw Error(data.error?.message || 'Test sign-in failed');
  users.push(data);
  return data;
}
async function call(email, user) {
  const response = await fetch(`https://asia-southeast1-${project}.cloudfunctions.net/createAdminInvite`, {
    method: 'POST', headers: {'Content-Type': 'application/json', ...(user ? {Authorization: `Bearer ${user.idToken}`} : {})},
    body: JSON.stringify({data: {storeId, email}}),
  });
  return {status: response.status, data: await response.json()};
}
(async () => {
  client.setCredentials({access_token: await token(), expiry_date: Date.now() + 3500000});
  const store = db.collection('stores').doc(storeId);
  try {
    const owner = await signUp();
    const target = await signUp();
    const outsider = await signUp();
    await store.set({name: 'Temporary admin invitation verification', status: 'active', ownerUid: owner.localId});
    await store.collection('members').doc(owner.localId).set({userId: owner.localId, storeId, role: 'owner', isActive: true});
    assert.equal((await call(target.email)).status, 401);
    assert.equal((await call(target.email, outsider)).status, 403);
    await store.collection('members').doc(outsider.localId).set({userId: outsider.localId, storeId, role: 'staff', isActive: true});
    assert.equal((await call(target.email, outsider)).status, 403);
    const missing = `stockwise-missing-${randomUUID()}@example.invalid`;
    const rejected = await call(missing, owner);
    assert.equal(rejected.status, 404, JSON.stringify(rejected));
    assert.equal(rejected.data.error.details.reason, 'email-not-found');
    assert.equal((await store.collection('adminInvites').doc(missing).get()).exists, false);
    const valid = await call(`  ${target.email.toUpperCase()}  `, owner);
    assert.equal(valid.status, 200, JSON.stringify(valid));
    assert.equal(valid.data.result.invited, true);
    const invite = (await store.collection('adminInvites').doc(target.email).get()).data();
    assert.equal(invite.status, 'pending');
    assert.equal(invite.emailLowercase, target.email);
    await store.collection('members').doc(target.localId).set({userId: target.localId, storeId, role: 'admin', isActive: true});
    assert.equal((await call(target.email, owner)).status, 409);
    assert.equal((await call(owner.email, owner)).status, 409);
    console.log('PASS: live registered account lookup, nonexistent email rejection, normalized invitation and admin-only access.');
  } finally {
    assert.ok(storeId.startsWith('invite_test_'));
    await db.recursiveDelete(store);
    for (const user of users) {
      assert.ok(user.email.startsWith('stockwise-invite-test-'));
      await getAuth().deleteUser(user.localId);
    }
    console.log('Temporary test accounts/store removed.');
  }
})().catch(error => {console.error(error.message); process.exitCode = 1;});
