// Checks profile persistence and avatar ownership with temporary accounts only. Sends no email.
const assert = require('node:assert/strict');
const {randomUUID} = require('node:crypto');
const backendRequire = require('node:module').createRequire(require('node:path').join(__dirname, '../functions/package.json'));
const {initializeApp} = backendRequire('firebase-admin/app');
const {getAuth} = backendRequire('firebase-admin/auth');
const {token, project} = require('./cloud-access.cjs');
const apiKey = require('../android/app/google-services.json').client[0].api_key[0].current_key;
const bucket = `${project}.firebasestorage.app`;
initializeApp({projectId: project, credential: {getAccessToken: async () => ({access_token: await token(), expires_in: 3500})}});
const users = [];
const avatars = [];
async function jsonRequest(url, body, idToken, method = 'POST') {
  const response = await fetch(url, {method, headers: {'Content-Type': 'application/json', ...(idToken ? {Authorization: `Bearer ${idToken}`} : {})}, body: body ? JSON.stringify(body) : undefined});
  return {status: response.status, data: await response.json()};
}
async function signUp() {
  const email = `stockwise-profile-test-${randomUUID()}@example.invalid`;
  const password = randomUUID() + 'Aa9!';
  const result = await jsonRequest(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`, {email, password, returnSecureToken: true});
  assert.equal(result.status, 200, 'Temporary sign-up failed');
  const user = {...result.data, password}; users.push(user); return user;
}
const profileUrl = uid => `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents/users/${uid}`;
const storageUrl = path => `https://firebasestorage.googleapis.com/v0/b/${bucket}/o/${encodeURIComponent(path)}`;
const pixels = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aWQAAAABJRU5ErkJggg==', 'base64');
async function upload(path, user, contentType = 'image/png') {
  return fetch(`https://firebasestorage.googleapis.com/v0/b/${bucket}/o?uploadType=media&name=${encodeURIComponent(path)}`, {
    method: 'POST', headers: {Authorization: `Firebase ${user.idToken}`, 'Content-Type': contentType}, body: pixels,
  });
}
(async () => {
  try {
    const owner = await signUp(); const other = await signUp();
    const path = `user-avatars/${owner.localId}/profile-test-${randomUUID()}.png`;
    avatars.push(path);
    const seed = await jsonRequest(profileUrl(owner.localId), {fields: {
      displayName: {stringValue: 'Original Name'}, email: {stringValue: owner.email},
      preferences: {mapValue: {fields: {expiryAlerts: {booleanValue: false}}}},
    }}, owner.idToken, 'PATCH');
    assert.equal(seed.status, 200, 'Own profile creation failed');
    assert.equal((await upload(path, other)).status, 403, 'Another account must not upload this avatar');
    assert.equal((await upload(path, owner, 'text/plain')).status, 403, 'Non-image uploads must be rejected');
    const uploaded = await upload(path, owner);
    assert.equal(uploaded.status, 200, 'Own avatar upload failed');
    const updated = await jsonRequest(`https://identitytoolkit.googleapis.com/v1/accounts:update?key=${apiKey}`, {
      idToken: owner.idToken, displayName: 'Edited Name', returnSecureToken: true,
    });
    assert.equal(updated.status, 200, 'Auth name update failed');
    const mask = '?updateMask.fieldPaths=displayName&updateMask.fieldPaths=phoneNumber&updateMask.fieldPaths=photoPath';
    const fields = {displayName: {stringValue: 'Edited Name'}, phoneNumber: {stringValue: '+60 12-345 6789'}, photoPath: {stringValue: path}};
    assert.equal((await jsonRequest(profileUrl(owner.localId) + mask, {fields}, owner.idToken, 'PATCH')).status, 200, 'Own profile edit failed');
    assert.equal((await jsonRequest(profileUrl(owner.localId) + mask, {fields}, other.idToken, 'PATCH')).status, 403, 'Another account must not edit this profile');
    const signedIn = await jsonRequest(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`, {
      email: owner.email, password: owner.password, returnSecureToken: true,
    });
    assert.equal(signedIn.status, 200, 'Re-login failed');
    assert.equal(signedIn.data.displayName, 'Edited Name');
    const persisted = await jsonRequest(profileUrl(owner.localId), null, signedIn.data.idToken, 'GET');
    assert.equal(persisted.data.fields.displayName.stringValue, 'Edited Name');
    assert.equal(persisted.data.fields.phoneNumber.stringValue, '+60 12-345 6789');
    assert.equal(persisted.data.fields.photoPath.stringValue, path);
    assert.equal(persisted.data.fields.preferences.mapValue.fields.expiryAlerts.booleanValue, false);
    assert.equal(persisted.data.fields.email.stringValue, owner.email);
    assert.equal((await fetch(storageUrl(path), {method: 'DELETE', headers: {Authorization: `Firebase ${other.idToken}`}})).status, 403);
    const removed = await fetch(storageUrl(path), {method: 'DELETE', headers: {Authorization: `Firebase ${owner.idToken}`}});
    assert.ok([200, 204].includes(removed.status), 'Own previous avatar cleanup failed');
    console.log('PASS: live name/phone/photo persistence after login, preserved preferences and profile/avatar ownership.');
  } finally {
    const access = await token();
    for (const path of avatars) {
      assert.ok(users.some(user => path.startsWith(`user-avatars/${user.localId}/profile-test-`)));
      const response = await fetch(`https://storage.googleapis.com/storage/v1/b/${bucket}/o/${encodeURIComponent(path)}`, {method: 'DELETE', headers: {Authorization: `Bearer ${access}`}});
      assert.ok([200, 204, 404].includes(response.status), 'Temporary avatar cleanup failed');
    }
    for (const user of users) {
      assert.ok(user.email.startsWith('stockwise-profile-test-'));
      const response = await fetch(profileUrl(user.localId), {method: 'DELETE', headers: {Authorization: `Bearer ${access}`}});
      assert.ok([200, 204, 404].includes(response.status), 'Temporary profile cleanup failed');
      await getAuth().deleteUser(user.localId);
    }
    console.log('Temporary test accounts/profiles/photos removed.');
  }
})().catch(error => {console.error(error.message); process.exitCode = 1;});
