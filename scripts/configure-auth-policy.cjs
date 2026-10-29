// Uses the same isolated Firebase account as the existing project helpers.
const path = require('node:path');
const {createRequire} = require('node:module');
const backendRequire = createRequire(path.join(__dirname, '../functions/package.json'));
const {initializeApp} = backendRequire('firebase-admin/app');
const {getAuth} = backendRequire('firebase-admin/auth');
const {token, project} = require('./cloud-access.cjs');

initializeApp({
  projectId: project,
  credential: {getAccessToken: async () => ({access_token: await token(), expires_in: 3500})},
});

(async () => {
  const manager = getAuth().projectConfigManager();
  const before = await manager.getProjectConfig();
  const previous = before.passwordPolicyConfig || {};
  const desired = {
    enforcementState: 'ENFORCE',
    forceUpgradeOnSignin: false,
    constraints: {
      ...previous.constraints,
      minLength: Math.max(8, previous.constraints?.minLength || 0),
      requireUppercase: true,
      requireLowercase: true,
      requireNumeric: true,
      requireNonAlphanumeric: true,
    },
  };
  if (!process.argv.includes('--apply')) {
    console.log(JSON.stringify({project,previous,desired,mode: 'preview'}));
    return;
  }
  await manager.updateProjectConfig({passwordPolicyConfig: desired});
  const verified = await manager.getProjectConfig();
  const policy = verified.passwordPolicyConfig;
  const c = policy?.constraints;
  if (policy?.enforcementState !== 'ENFORCE' || policy.forceUpgradeOnSignin
      || c?.minLength < 8 || !c?.requireUppercase || !c?.requireLowercase
      || !c?.requireNumeric || !c?.requireNonAlphanumeric) {
    throw Error('Password policy read-back did not match the requested rules.');
  }
  console.log(JSON.stringify({project,passwordPolicyConfig: policy,verified: true}));
})().catch(error => {console.error(error.message); process.exitCode = 1;});
