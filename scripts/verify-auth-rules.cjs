// Creates and removes temporary Auth users. Never sends verification/reset email.
const assert = require('node:assert/strict');
const {randomUUID, createHmac} = require('node:crypto');
const {createRequire} = require('node:module');
const path = require('node:path');
const backendRequire = createRequire(path.join(__dirname, '../functions/package.json'));
const {initializeApp} = backendRequire('firebase-admin/app');
const {getAuth} = backendRequire('firebase-admin/auth');
const {project, token} = require('./cloud-access.cjs');
const apiKey = require('../android/app/google-services.json').client[0].api_key[0].current_key;
initializeApp({
  projectId: project,
  credential: {getAccessToken: async () => ({access_token: await token(), expires_in: 3500})},
});
const auth = getAuth(), created = new Set();
const email = 'stockwise-auth-test-' + randomUUID() + '@example.invalid';
const missing = 'stockwise-missing-' + randomUUID() + '@example.invalid';

async function identity(action, body) {
  const response = await fetch('https://identitytoolkit.googleapis.com/v1/accounts:' + action + '?key=' + apiKey, {
    method: 'POST', headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({...body, returnSecureToken: true}),
  });
  const data = await response.json();
  if (action === 'signUp' && data.localId) created.add(data.localId);
  return {status: response.status, data};
}
async function lookup(value) {
  const response = await fetch('https://asia-southeast1-' + project + '.cloudfunctions.net/checkRegisteredEmail', {
    method: 'POST', headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({data: {email: value}}),
  });
  return {status: response.status, data: await response.json()};
}

(async () => {
  try {
    const absent = await lookup(missing);
    assert.equal(absent.status, 200);
    assert.deepEqual(absent.data.result, {registered: false});
    assert.equal((await lookup('missing/name+tag-' + randomUUID() + '@example.invalid')).status, 200);
    for (const password of ['Abcd1!x', 'abcdef1!', 'ABCDEF1!', 'Abcdefg!', 'Abcdef12']) {
      const rejected = await identity('signUp', {email, password});
      assert.equal(rejected.status, 400, 'Firebase must reject each missing password criterion.');
      assert.match(rejected.data.error?.message || '', /PASSWORD_DOES_NOT_MEET_REQUIREMENTS|WEAK_PASSWORD/);
    }
    const registered = await identity('signUp', {email, password: 'Abcdef1!'});
    assert.equal(registered.status, 200, 'A compliant eight-character password must work.');
    const found = await lookup(' ' + email.toUpperCase() + ' ');
    assert.equal(found.status, 200);
    assert.deepEqual(found.data.result, {registered: true});
    assert.equal((await lookup('invalid')).status, 400);

    // Import a legacy password hash: ordinary creation correctly enforces the new policy.
    const legacyEmail = 'stockwise-legacy-test-' + randomUUID() + '@example.invalid';
    const legacyUid = 'auth-rules-legacy-' + randomUUID();
    const key = Buffer.from(randomUUID());
    const imported = await auth.importUsers([{
      uid: legacyUid, email: legacyEmail,
      passwordHash: createHmac('sha256', key).update('Oldpass1').digest(),
    }], {hash: {algorithm: 'HMAC_SHA256', key}});
    if (imported.successCount) created.add(legacyUid);
    assert.equal(imported.failureCount, 0, 'The temporary legacy fixture must import successfully.');
    const login = await identity('signInWithPassword', {email: legacyEmail, password: 'Oldpass1'});
    assert.equal(login.status, 200, 'Existing accounts must not be forced to upgrade on login.');

    await auth.deleteUser(registered.data.localId);
    created.delete(registered.data.localId);
    assert.deepEqual((await lookup(email)).data.result, {registered: false});
    console.log('PASS: live registered/missing/deleted lookup, all 5 password rules, valid signup and legacy login.');
  } finally {
    const failures = [];
    for (const uid of created) {
      try { await auth.deleteUser(uid); } catch (_) { failures.push(uid); }
    }
    if (failures.length) throw Error('Temporary Auth account cleanup needs attention.');
    console.log('Temporary Auth users removed; no emails sent.');
  }
})().catch(error => {console.error(error.message); process.exitCode = 1;});
