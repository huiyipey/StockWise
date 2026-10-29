// Uses Firebase's own sender; no SMTP credential or new email provider is needed.
const fs = require('node:fs');
const path = require('node:path');
const {isDeepStrictEqual} = require('node:util');
const {createRequire} = require('node:module');
const backendRequire = createRequire(path.join(__dirname, '../functions/package.json'));
const {initializeApp} = backendRequire('firebase-admin/app');
const {getAuth} = backendRequire('firebase-admin/auth');
const {Firestore, FieldValue} = backendRequire('@google-cloud/firestore');
const {GoogleAuth, OAuth2Client} = backendRequire('google-auth-library');
const {api, token, project} = require('./cloud-access.cjs');
const {LEGACY_CLAIM} = require('../functions/email_verification');
const root = path.join(__dirname, '..');
const google = JSON.parse(fs.readFileSync(path.join(root, 'android/app/google-services.json'), 'utf8'));
const apiKey = google.client[0].api_key[0].current_key;
const authDomain = `${project}.firebaseapp.com`;
const origin = `https://${project}.web.app`;
const actionUrl = origin + '/';
// These are public Firebase web configuration values, never admin credentials.
fs.writeFileSync(path.join(root, 'functions/auth_web_config.json'), JSON.stringify({apiKey})+'\n');
fs.writeFileSync(path.join(root, 'web_auth/config.js'), 'window.STOCKWISE_AUTH_CONFIG = '+JSON.stringify({apiKey, authDomain})+';\n');
fs.copyFileSync(path.join(root, 'assets/branding/auth_logo.png'), path.join(root, 'web_auth/auth_logo.png'));
if (process.argv.includes('--assets')) {
  console.log('Public verification page assets generated. No cloud settings changed.');
  return;
}
initializeApp({projectId: project, credential: {getAccessToken: async () => ({access_token: await token(), expires_in: 3500})}});

(async () => {
  const client = new OAuth2Client();
  client.setCredentials({access_token: await token()});
  const db = new Firestore({projectId: project, preferRest: true, auth: new GoogleAuth({authClient: client})});
  const auth = getAuth();
  const policy = db.collection('authPolicies').doc('emailVerification');
  if (!process.argv.includes('--apply')) {
    const existing = await policy.get();
    console.log(JSON.stringify({project, mode: 'preview', initialized: existing.exists, actionUrl}));
    return;
  }
  // Fixed on first rollout; rerunning must never exempt accounts created later.
  await db.runTransaction(async tx => {
    if (!(await tx.get(policy)).exists) tx.create(policy, {cutoff: new Date(), createdAt: FieldValue.serverTimestamp()});
  });
  const cutoff = (await policy.get()).data().cutoff.toDate().getTime();
  let pageToken, preserved = 0;
  do {
    const page = await auth.listUsers(1000, pageToken);
    for (const record of page.users) {
      if (Date.parse(record.metadata.creationTime) < cutoff && record.customClaims?.[LEGACY_CLAIM] !== true) {
        // Merge claims; store roles or other existing claims must not be discarded.
        const current = await auth.getUser(record.uid);
        await auth.setCustomUserClaims(record.uid, {...current.customClaims, [LEGACY_CLAIM]: true});
        preserved++;
      }
    }
    pageToken = page.pageToken;
  } while (pageToken);
  const configUrl = `https://identitytoolkit.googleapis.com/admin/v2/projects/${project}/config`;
  const before = await api(configUrl);
  // The managed sender allows its display name to be set. This project's
  // provider rejects custom verification bodies, subjects and callback URLs.
  await api(configUrl+'?updateMask=notification.sendEmail.verifyEmailTemplate.senderDisplayName', 'PATCH', {
    notification: {sendEmail: {verifyEmailTemplate: {senderDisplayName: 'StockWise'}}},
  });
  const after = await api(configUrl);
  if (after.notification?.sendEmail?.verifyEmailTemplate?.senderDisplayName !== 'StockWise') {
    throw Error('Verification email settings did not match after saving.');
  }
  const policySettings = ({lastUpdateTime, ...settings} = {}) => settings;
  // Identity Platform changes this informational timestamp for any config update.
  if (!isDeepStrictEqual(policySettings(after.passwordPolicyConfig), policySettings(before.passwordPolicyConfig))
      || !isDeepStrictEqual(after.emailPrivacyConfig, before.emailPrivacyConfig)) {
    throw Error('Unrelated authentication settings changed unexpectedly.');
  }
  console.log(JSON.stringify({project, existingAccountsPreserved: preserved, verificationEmailConfigured: true, fullyBrandedEmail: false, managedEmailActionPage: true, continuationUrl: origin}));
})().catch(error => {console.error(error.message); process.exitCode=1;});

