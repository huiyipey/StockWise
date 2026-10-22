// Local administrative helper: explicitly uses the project's isolated Firebase account.
// Never logs or writes access/refresh tokens.
const path = require('node:path');
const auth = require(path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools/lib/auth.js'));
const project = 'stockwise-190a9';
async function token() {
  const account = auth.getAllAccounts().find(a => a.user.email === 'huiyipey@gmail.com');
  if (!account) throw Error('Sign in to Firebase CLI as huiyipey@gmail.com first.');
  const result = await auth.getAccessToken(account.tokens.refresh_token, ['https://www.googleapis.com/auth/cloud-platform']);
  return result.access_token;
}
async function api(url, method = 'GET', body) {
  const response = await fetch(url, {method, headers: {Authorization: `Bearer ${await token()}`, 'Content-Type': 'application/json'}, body: body ? JSON.stringify(body) : undefined});
  const data = await response.json();
  if (!response.ok) throw Error(`${response.status}: ${data.error?.message || 'Cloud request failed'}`);
  return data;
}
module.exports = {api, token, project};
if (require.main === module) {
  (async () => {
    for (const service of ['aiplatform.googleapis.com', 'secretmanager.googleapis.com']) {
      const result = await api(`https://serviceusage.googleapis.com/v1/projects/${project}/services/${service}:enable`, 'POST', {});
      console.log(`${service}: ${result.name || 'enabled'}`);
    }
  })().catch(e => {console.error(e.message); process.exitCode = 1;});
}
