// Publishes the pinned postcode-to-State index used by Firestore address rules.
// No customer records or credentials are exported.
const {createHash} = require('node:crypto');

function buildPostcodeValidation(postcodes = require('../functions/data/malaysia_postcodes.json')) {
  const states = {};
  for (const [code, location] of Object.entries(postcodes)) {
    if (!/^\d{5}$/.test(code) || !Array.isArray(location) || location.length !== 2 ||
        location.some(value => typeof value !== 'string' || !value.trim())) {
      throw Error('Invalid entry in the pinned Malaysian postcode dataset.');
    }
    states[code] = location[1];
  }
  const result = {states, entryCount: Object.keys(states).length,
    sourceSha256: createHash('sha256').update(JSON.stringify(postcodes)).digest('hex')};
  if (!result.entryCount || Buffer.byteLength(JSON.stringify(result)) > 800000) {
    throw Error('Postcode validation index is empty or exceeds its document budget.');
  }
  return result;
}

async function main() {
  const path = require('node:path');
  const backend = require('node:module').createRequire(path.resolve(__dirname, '../functions/package.json'));
  const {Firestore, FieldValue} = backend('@google-cloud/firestore');
  const {GoogleAuth, OAuth2Client} = backend('google-auth-library');
  const {token, project} = require('./cloud-access.cjs');
  const client = new OAuth2Client();
  client.setCredentials({access_token: await token(), expiry_date: Date.now() + 3500000});
  const db = new Firestore({projectId: project, preferRest: true, auth: new GoogleAuth({authClient: client})});
  try {
    const data = buildPostcodeValidation();
    await db.doc('validationData/malaysiaPostcodes').set({...data, updatedAt: FieldValue.serverTimestamp()});
    console.log(JSON.stringify({document: 'validationData/malaysiaPostcodes', entryCount: data.entryCount, sourceSha256: data.sourceSha256}));
  } finally { await db.terminate(); }
}

module.exports = {buildPostcodeValidation};
if (require.main === module) main().catch(error => {console.error(error.message); process.exitCode = 1;});
