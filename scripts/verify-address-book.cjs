// Uses only temporary accounts/address records and sends no email.
const assert = require('node:assert/strict');
const {randomUUID} = require('node:crypto');
const backendRequire = require('node:module').createRequire(require('node:path').join(__dirname, '../functions/package.json'));
const {initializeApp} = backendRequire('firebase-admin/app');
const {getAuth} = backendRequire('firebase-admin/auth');
const {token, project} = require('./cloud-access.cjs');
const apiKey = require('../android/app/google-services.json').client[0].api_key[0].current_key;
initializeApp({projectId: project, credential: {getAccessToken: async () => ({access_token: await token(), expires_in: 3500})}});
const users = [];
const base = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;
const prefix = `projects/${project}/databases/(default)/documents`;
async function request(url, body, idToken, method = 'POST') {
  const response = await fetch(url, {method, headers: {'Content-Type': 'application/json', ...(idToken ? {Authorization: `Bearer ${idToken}`} : {})}, body: body ? JSON.stringify(body) : undefined});
  const text = await response.text();
  return {status: response.status, data: text ? JSON.parse(text) : null};
}
async function signUp() {
  const email = `stockwise-address-test-${randomUUID()}@example.invalid`;
  const password = randomUUID() + 'Aa9!';
  const result = await request(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`, {email, password, returnSecureToken: true});
  assert.equal(result.status, 200, 'Temporary sign-up failed');
  const user = {...result.data, password}; users.push(user); return user;
}
const strings = data => Object.fromEntries(Object.entries(data).map(([key, value]) => [key, {stringValue: value}]));
const addressData = label => strings({label, name: 'Test Recipient', phone: '0123456789', addressLine1: `12 ${label} Street`, city: 'Kuala Lumpur', state: 'Kuala Lumpur', postalCode: '50000', countryCode: 'MY'});
async function commit(writes, user) { return request(base + ':commit', {writes}, user.idToken); }
(async () => {
  try {
    const owner = await signUp(); const other = await signUp();
    const path = `users/${owner.localId}`;
    const name = `${prefix}/${path}`;
    const seed = await request(`${base}/${path}`, {fields: {
      displayName: {stringValue: 'Test Recipient'}, preferences: {mapValue: {fields: {expiryAlerts: {booleanValue: false}}}},
    }}, owner.idToken, 'PATCH');
    assert.equal(seed.status, 200);
    const first = await commit([
      {update: {name: `${name}/addresses/home`, fields: addressData('Home')}},
      {update: {name, fields: strings({defaultAddressId: 'home'})}, updateMask: {fieldPaths: ['defaultAddressId']}},
    ], owner);
    assert.equal(first.status, 200, 'First address/default save failed');
    assert.equal((await commit([{update: {name: `${name}/addresses/work`, fields: addressData('Work')}}], owner)).status, 200);
    assert.equal((await request(`${base}/${path}/addresses`, null, owner.idToken, 'GET')).data.documents.length, 2);
    assert.equal((await request(`${base}/${path}/addresses`, null, other.idToken, 'GET')).status, 403);
    assert.equal((await commit([{update: {name: `${name}/addresses/home`, fields: addressData('Changed')}}], other)).status, 403);
    assert.equal((await commit([{update: {name, fields: strings({defaultAddressId: 'work'})}, updateMask: {fieldPaths: ['defaultAddressId']}}], owner)).status, 200);
    assert.equal((await commit([{update: {name: `${name}/addresses/work`, fields: strings({addressLine1: '34 Edited Street'})}, updateMask: {fieldPaths: ['addressLine1']}}], owner)).status, 200);
    const login = await request(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`, {email: owner.email, password: owner.password, returnSecureToken: true});
    assert.equal(login.status, 200);
    const profile = await request(`${base}/${path}`, null, login.data.idToken, 'GET');
    assert.equal(profile.data.fields.defaultAddressId.stringValue, 'work');
    assert.equal(profile.data.fields.preferences.mapValue.fields.expiryAlerts.booleanValue, false);
    const saved = await request(`${base}/${path}/addresses/work`, null, login.data.idToken, 'GET');
    assert.equal(saved.data.fields.addressLine1.stringValue, '34 Edited Street');
    assert.equal(saved.data.fields.phone.stringValue, '0123456789');
    assert.equal(saved.data.fields.postalCode.stringValue, '50000');
    assert.equal((await commit([{delete: `${name}/addresses/work`}], other)).status, 403);
    assert.equal((await commit([{delete: `${name}/addresses/work`}, {update: {name, fields: strings({defaultAddressId: 'home'})}, updateMask: {fieldPaths: ['defaultAddressId']}}], owner)).status, 200);
    assert.equal((await request(`${base}/${path}`, null, owner.idToken, 'GET')).data.fields.defaultAddressId.stringValue, 'home');
    assert.equal((await commit([{delete: `${name}/addresses/home`}, {update: {name, fields: {}}, updateMask: {fieldPaths: ['defaultAddressId']}}], owner)).status, 200);
    assert.equal((await request(`${base}/${path}`, null, owner.idToken, 'GET')).data.fields.defaultAddressId, undefined);
    console.log('PASS: live saved addresses/default persistence, editing, deletion and account privacy.');
  } finally {
    const access = await token();
    for (const user of users) {
      assert.ok(user.email.startsWith('stockwise-address-test-'));
      for (const suffix of ['/addresses/home', '/addresses/work', '']) {
        const response = await request(`${base}/users/${user.localId}${suffix}`, null, access, 'DELETE');
        assert.ok([200, 204, 404].includes(response.status), 'Temporary address/profile cleanup failed');
      }
      await getAuth().deleteUser(user.localId);
    }
    console.log('Temporary test accounts/addresses/profiles removed.');
  }
})().catch(error => {console.error(error.message); process.exitCode = 1;});
