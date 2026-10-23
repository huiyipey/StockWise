// Receives the key through stdin; never stores it in workspace files or logs it.
if (process.stdin.isTTY) process.stdin.setRawMode(true);
const readline = require('node:readline');
const {api, project} = require('./cloud-access.cjs');
async function main(key) {
  if (!key || key.length > 512) throw Error('A valid Gemini API key is required.');
  const headers = {'x-goog-api-key': key, 'Content-Type': 'application/json'};
  const modelsResponse = await fetch('https://generativelanguage.googleapis.com/v1beta/models', {headers, signal: AbortSignal.timeout(30000)});
  const models = await modelsResponse.json();
  if (!modelsResponse.ok) throw Error(`Gemini key verification failed: HTTP ${modelsResponse.status}, ${models.error?.status || 'provider_error'}.`);
  const available = new Set((models.models || []).filter(model => model.supportedGenerationMethods?.includes('generateContent')).map(model => model.name.replace('models/', '')));
  const candidates = ['gemini-3.5-flash-lite', 'gemini-3.1-flash-lite', 'gemini-3.8-flash', 'gemini-2.5-flash-lite', 'gemini-2.5-flash', 'gemini-3-flash-preview'].filter(name => available.has(name));
  if (!candidates.length) throw Error('No supported text model is available to this key.');
  let model;
  for (const candidate of candidates) {
  const check = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${candidate}:generateContent`, {
    method: 'POST', headers, signal: AbortSignal.timeout(45000),
    body: JSON.stringify({contents: [{role: 'user', parts: [{text: 'Reply with only the result of 2 + 2.'}]}],
      generationConfig: {maxOutputTokens: 512, ...(candidate.startsWith('gemini-2.5') ? {thinkingConfig: {thinkingBudget: 0}} : {})}}),
  });
  const reply = await check.json();
  if (check.status === 404) { console.log(`${candidate} is unavailable to this key; checking the next text model.`); continue; }
  if (!check.ok) throw Error(`Gemini generation failed: HTTP ${check.status}, ${reply.error?.status || 'provider_error'}.`);
  if (!reply.candidates?.some(candidate => candidate.content?.parts?.some(part => part.text?.trim()))) throw Error('Gemini returned no text during verification.');
  model = candidate;
  break;
  }
  if (!model) throw Error('Listed text models could not generate a response with this key.');
  const secret = `projects/${project}/secrets/GEMINI_API_KEY`;
  try { await api(`https://secretmanager.googleapis.com/v1/${secret}`); }
  catch (error) {
    if (!error.message.startsWith('404:')) throw error;
    await api(`https://secretmanager.googleapis.com/v1/projects/${project}/secrets?secretId=GEMINI_API_KEY`, 'POST', {replication: {automatic: {}}});
  }
  await api(`https://secretmanager.googleapis.com/v1/${secret}:addVersion`, 'POST', {payload: {data: Buffer.from(key).toString('base64')}});
  const func = await api(`https://cloudfunctions.googleapis.com/v2/projects/${project}/locations/asia-southeast1/functions/shoppingAssistant`);
  const account = func.serviceConfig.serviceAccountEmail;
  if (!account) throw Error('Shopping assistant runtime account could not be identified.');
  const policy = await api(`https://secretmanager.googleapis.com/v1/${secret}:getIamPolicy`);
  const bindings = policy.bindings || [];
  let access = bindings.find(binding => binding.role === 'roles/secretmanager.secretAccessor' && !binding.condition);
  if (!access) { access = {role: 'roles/secretmanager.secretAccessor', members: []}; bindings.push(access); }
  const member = `serviceAccount:${account}`;
  if (!access.members.includes(member)) {
    access.members.push(member);
    await api(`https://secretmanager.googleapis.com/v1/${secret}:setIamPolicy`, 'POST', {policy: {...policy, bindings}});
  }
  console.log(`PASS: Gemini key verified with ${model}; stored in Secret Manager with access for the assistant runtime only.`);
}
const input = readline.createInterface({input: process.stdin, terminal: false});
console.log('Ready for the key through protected stdin.');
input.once('line', line => {
  if (process.stdin.isTTY) process.stdin.setRawMode(false);
  input.close();
  main(line.trim()).catch(error => { console.error(error.message); process.exitCode = 1; });
});
