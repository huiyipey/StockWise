// Canonicalize only recognized shop-administration roles. Dry run by default.
// Membership activation, report preferences, creator attribution and all other
// fields are preserved. Update-time preconditions prevent overwriting a change
// made by an administrator while this migration is running.
const legacyAdminRoles = new Set(['owner', 'manager', 'staff']);

// Choose role-only changes while preserving membership preferences.
function migrationFor(documentPath, data) {
  if (!/^stores\/[^/]+\/(members|adminInvites)\/[^/]+$/.test(documentPath)) return null;
  if (!legacyAdminRoles.has(data?.role)) return null;
  return {path: documentPath, previousRole: data.role, role: 'admin'};
}

// Preview or apply the role-only Admin migration.
async function main() {
  const path = require('node:path');
  const fs = require('node:fs');
  const backend = require('node:module').createRequire(path.resolve(__dirname, '../functions/package.json'));
  const {Firestore} = backend('@google-cloud/firestore');
  const {GoogleAuth, OAuth2Client} = backend('google-auth-library');
  const {token, project} = require('./cloud-access.cjs');
  const apply = process.argv.includes('--apply');
  const outputIndex = process.argv.indexOf('--output');
  const client = new OAuth2Client();
  client.setCredentials({access_token: await token(), expiry_date: Date.now() + 3500000});
  const db = new Firestore({projectId: project, preferRest: true, auth: new GoogleAuth({authClient: client})});
  const summary = {project, applied: apply, inspected: 0, roles: {}, planned: 0, updated: 0, conflicts: 0, remainingLegacy: 0};
  for (const collection of ['members', 'adminInvites']) {
    const snapshot = await db.collectionGroup(collection).get();
    for (const document of snapshot.docs) {
      if (!/^stores\/[^/]+\/(members|adminInvites)\/[^/]+$/.test(document.ref.path)) continue;
      summary.inspected++;
      const data = document.data();
      const key = `${collection}:${typeof data.role === 'string' ? data.role : '(missing)'}:${data.isActive === false ? 'inactive' : 'other'}`;
      summary.roles[key] = (summary.roles[key] || 0) + 1;
      if (!migrationFor(document.ref.path, data)) continue;
      summary.planned++;
      if (apply) {
        try {
          await document.ref.update({role: 'admin'}, {lastUpdateTime: document.updateTime});
          summary.updated++;
        } catch (error) {
          if (error.code === 9 || error.code === 5) summary.conflicts++;
          else throw error;
        }
      }
    }
  }
  if (apply) {
    for (const collection of ['members', 'adminInvites']) {
      const snapshot = await db.collectionGroup(collection).get();
      summary.remainingLegacy += snapshot.docs.filter(document => migrationFor(document.ref.path, document.data())).length;
    }
  }
  // Aggregate output intentionally excludes shop/user identifiers and emails.
  console.log(JSON.stringify(summary, null, 2));
  if (outputIndex !== -1) {
    const output = path.resolve(process.argv[outputIndex + 1]);
    fs.mkdirSync(path.dirname(output), {recursive: true});
    fs.writeFileSync(output, JSON.stringify(summary, null, 2) + '\n');
  }
  await db.terminate();
  if (apply && (summary.conflicts || summary.remainingLegacy)) process.exitCode = 1;
}

// Export the helpers used by the app backend and tests.
module.exports = {migrationFor};
if (require.main === module) main().catch(error => {console.error(error.message); process.exitCode = 1;});
