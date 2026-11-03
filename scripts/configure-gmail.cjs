// Receives credentials through stdin only. Never writes them to disk or logs them.
const {api, token, project} = require('./cloud-access.cjs');
const nodemailer = require('../functions/node_modules/nodemailer');
const {sampleConfirmation} = require('./order-email-sample.cjs');
function saveSetupResult(result) {
  const fs = require('node:fs'), path = require('node:path');
  const folder = path.resolve(__dirname, '../tmp/order-confirmation-email-2026-11-03');
  fs.mkdirSync(folder, {recursive: true});
  fs.writeFileSync(path.join(folder, 'gmail-setup-result.json'), JSON.stringify({...result, checkedAt: new Date().toISOString()}, null, 2));
}
async function configure(input) {
  const user = String(input.email || '').trim().toLowerCase();
  const password = String(input.password || '').replace(/\s/g, '');
  if (!/^[^\s@]+@gmail\.com$/.test(user) || !/^[a-z]{16}$/i.test(password)) {
    throw Error('Use the app Gmail address and its 16-character Google app password.');
  }
  const testEmail = String(input.testEmail || '').trim().toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(testEmail)) throw Error('Enter the customer login email for the delivery test.');
  const backend = require('node:module').createRequire(require('node:path').resolve(__dirname, '../functions/package.json'));
  const {initializeApp, deleteApp} = backend('firebase-admin/app');
  const {getAuth} = backend('firebase-admin/auth');
  const app = initializeApp({projectId: project, credential: {getAccessToken: async () => ({access_token: await token(), expires_in: 3500})}}, 'gmail-setup');
  let customer;
  try { customer = await getAuth(app).getUserByEmail(testEmail); }
  catch (_) { throw Error('Enter an existing StockWise customer login email for the delivery test.'); }
  finally { await deleteApp(app); }
  if (customer.disabled || !customer.emailVerified) throw Error('The test customer account must be enabled and its email verified.');
  const config = {host: 'smtp.gmail.com', port: 465, secure: true,
    user, password, from: `StockWise <${user}>`};
  const transport = nodemailer.createTransport({...config,
    auth: {user, pass: password}, connectionTimeout: 15000, socketTimeout: 30000});
  try { await transport.verify(); }
  catch (_) { throw Error('Gmail sign-in failed. Check the address, two-step verification and app password.'); }
  finally { transport.close(); }
  const base = `https://secretmanager.googleapis.com/v1/projects/${project}`;
  const secret = `${base}/secrets/REPORT_SMTP_CONFIG`;
  try { await api(secret); }
  catch (e) {
    if (!e.message.startsWith('404:')) throw e;
    await api(`${base}/secrets?secretId=REPORT_SMTP_CONFIG`, 'POST', {replication: {automatic: {}}});
  }
  // Grant only the mail functions' existing runtime identities access to this secret.
  const names = ['emailOrderConfirmation', 'retryOrderConfirmations', 'emailStoreReports'];
  const identities = new Set();
  for (const name of names) {
    const fn = await api(`https://cloudfunctions.googleapis.com/v2/projects/${project}/locations/asia-southeast1/functions/${name}`);
    if (fn.serviceConfig?.serviceAccountEmail) identities.add(`serviceAccount:${fn.serviceConfig.serviceAccountEmail}`);
  }
  if (!identities.size) throw Error('Could not identify the deployed mail runtime.');
  const policy = await api(`${secret}:getIamPolicy`);
  policy.bindings ||= [];
  let binding = policy.bindings.find(b => b.role === 'roles/secretmanager.secretAccessor' && !b.condition);
  if (!binding) policy.bindings.push(binding = {role: 'roles/secretmanager.secretAccessor', members: []});
  binding.members = [...new Set([...binding.members, ...identities])];
  await api(`${secret}:setIamPolicy`, 'POST', {policy});
  await api(`${secret}:addVersion`, 'POST', {payload: {data: Buffer.from(JSON.stringify(config)).toString('base64')}});
  const sender = nodemailer.createTransport({...config, auth: {user, pass: password}, connectionTimeout: 15000, socketTimeout: 30000});
  try {
    const message = sampleConfirmation({customerName: customer.displayName || 'StockWise Customer'});
    const result = await sender.sendMail({from: config.from, to: customer.email, ...message});
    if (!result.accepted?.some(address => String(address).toLowerCase() === customer.email.toLowerCase())) throw Error('The test recipient was not accepted.');
    return {configured: true, testAccepted: true, messageId: result.messageId || null};
  } catch (_) {
    throw Error('Gmail sender is configured, but test delivery failed. Check the customer address and Gmail account sending limits.');
  } finally { sender.close(); }
}
if (require.main === module) {
  (async () => {
    let raw = '';
    for await (const chunk of process.stdin) raw += chunk;
    const result = await configure(JSON.parse(raw));
    raw = null;
    saveSetupResult(result);
    console.log('Gmail sender configured. Gmail accepted the sample confirmation for the verified customer login email.');
    console.log('Check the customer Inbox and Spam folders. Please confirm in chat when the sample arrives.');
  })().catch(e => {
    // The HTTP and SMTP errors must never expose submitted configuration.
    const safe = /^(Use the app|Gmail sign-in|Could not identify|Enter |The test customer|Gmail sender is configured)/.test(e.message);
    const message = safe ? e.message : 'Cloud setup failed. Check the Firebase account permissions and try again.';
    saveSetupResult({configured: e.message.startsWith('Gmail sender is configured'), testAccepted: false, error: message});
    console.error(message);
    process.exitCode = 1;
  });
}
