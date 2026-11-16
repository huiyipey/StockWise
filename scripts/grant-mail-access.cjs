const {api, project} = require('./cloud-access.cjs');
(async () => {
  // Read the report function service account.
  const fn = await api(`https://cloudfunctions.googleapis.com/v2/projects/${project}/locations/asia-southeast1/functions/emailStoreReports`);
  const account = fn.serviceConfig?.serviceAccountEmail;
  if (!account) throw Error('Deploy emailStoreReports first.');
  const resource = `https://secretmanager.googleapis.com/v1/projects/${project}/secrets/REPORT_SMTP_CONFIG`;
  // Preserve the secret's existing access policy.
  const policy = await api(`${resource}:getIamPolicy`);
  policy.bindings ||= [];
  let binding = policy.bindings.find(b => b.role === 'roles/secretmanager.secretAccessor');
  if (!binding) {binding = {role: 'roles/secretmanager.secretAccessor', members: []}; policy.bindings.push(binding);}
  // Allow this function to read only the mail configuration secret.
  const member = `serviceAccount:${account}`;
  if (!binding.members.includes(member)) binding.members.push(member);
  await api(`${resource}:setIamPolicy`, 'POST', {policy});
  console.log('Report function can read the mail credential. No project-wide secret access was granted.');
})().catch(e => {console.error(e.message); process.exitCode = 1;});
