// Permit the verification function's existing service account to sign its own
// UID-bound continuation tokens. No project-wide Token Creator grant is added.
const {api, project} = require('./cloud-access.cjs');
(async () => {
  const fn = await api(`https://cloudfunctions.googleapis.com/v2/projects/${project}/locations/asia-southeast1/functions/manageEmailVerification`);
  const account = fn.serviceConfig?.serviceAccountEmail;
  if (!account || !account.endsWith('.gserviceaccount.com')) throw Error('Deploy manageEmailVerification first.');
  const resource = `https://iam.googleapis.com/v1/projects/${project}/serviceAccounts/${account}`;
  const policy = await api(resource+':getIamPolicy', 'POST', {});
  const member = 'serviceAccount:'+account;
  const role = 'roles/iam.serviceAccountTokenCreator';
  const present = policy.bindings?.some(b => b.role === role && !b.condition && b.members.includes(member));
  if (!process.argv.includes('--apply')) {
    console.log(JSON.stringify({project, configured: !!present, mode: 'preview'}));
    return;
  }
  const service = `https://serviceusage.googleapis.com/v1/projects/${project}/services/iamcredentials.googleapis.com`;
  if ((await api(service)).state !== 'ENABLED') await api(service+':enable', 'POST', {});
  if (!present) {
    policy.bindings ||= [];
    let binding = policy.bindings.find(b => b.role === role && !b.condition);
    if (!binding) {binding = {role, members: []}; policy.bindings.push(binding);}
    binding.members.push(member);
    await api(resource+':setIamPolicy', 'POST', {policy});
  }
  console.log('Verification session signing configured for the function service account only.');
})().catch(error => {console.error(error.message); process.exitCode = 1;});
