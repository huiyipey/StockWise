// Verifies password changes using a temporary account only. Sends no email.
const assert = require('node:assert/strict');
const {randomUUID} = require('node:crypto');
const backendRequire = require('node:module').createRequire(require('node:path').join(__dirname, '../functions/package.json'));
const {initializeApp} = backendRequire('firebase-admin/app');
const {getAuth} = backendRequire('firebase-admin/auth');
const {token, project} = require('./cloud-access.cjs');
const apiKey = require('../android/app/google-services.json').client[0].api_key[0].current_key;
initializeApp({projectId: project, credential: {getAccessToken: async () => ({access_token: await token(), expires_in: 3500})}});
async function request(action, body) {
  const response = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:${action}?key=${apiKey}`, {
    method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(body),
  });
  return {status: response.status, data: await response.json()};
}
let user;
(async () => {
  const email = `stockwise-password-test-${randomUUID()}@example.invalid`;
  const password = randomUUID() + 'Aa9!';
  const newPassword = ' ' + randomUUID() + ' Aa9! ';
  const signIn = candidate => request('signInWithPassword', {email, password: candidate, returnSecureToken: true});
  try {
    const signup = await request('signUp', {email, password, returnSecureToken: true});
    assert.equal(signup.status, 200, 'Temporary sign-up failed');
    user = signup.data;
    assert.equal((await signIn('wrong-' + randomUUID())).status, 400, 'Incorrect current password rejected');
    const current = await signIn(password);
    assert.equal(current.status, 200, 'Current password still valid after failed verification');
    assert.equal(current.data.localId, user.localId);
    const changed = await request('update', {idToken: current.data.idToken, password: newPassword, returnSecureToken: true});
    assert.equal(changed.status, 200, 'Password update failed');
    assert.equal(changed.data.localId, user.localId);
    assert.equal((await signIn(password)).status, 400, 'Old password no longer accepted');
    const newLogin = await signIn(newPassword);
    assert.equal(newLogin.status, 200, 'New password accepted');
    assert.equal(newLogin.data.localId, user.localId);
    assert.equal((await signIn(newPassword.trim())).status, 400, 'Password whitespace remains significant');
    console.log('PASS: live current-password verification, password change, old password rejection and new password login.');
  } finally {
    if (user) {
      assert.ok(user.email.startsWith('stockwise-password-test-'));
      await getAuth().deleteUser(user.localId);
      console.log('Temporary password test account removed.');
    }
  }
})().catch(error => {console.error(error.message); process.exitCode = 1;});
