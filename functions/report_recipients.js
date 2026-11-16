const {isActiveStoreAdmin} = require('./store_roles');
const {reportCadences} = require('./reporting');

// Select active admins and their authoritative Auth email addresses.
async function storeReportRecipients(store, auth) {
  const members = await store.collection('members').get();
  const result = [];
  // Creator attribution does not grant privileges or bypass membership settings.
  // Auth is the authority for recipients, never client-editable email fields.
  for (const doc of members.docs) {
    const member = doc.data();
    if (!isActiveStoreAdmin(member) || member.reportsByEmail === false) continue;
    try {
      const user = await auth.getUser(doc.id);
      if (user.email && !user.disabled) result.push({
        email: user.email.toLowerCase(),
        sales: reportCadences(member, 'sales'), waste: reportCadences(member, 'waste'),
      });
    } catch (error) {
      if (error.code !== 'auth/user-not-found') throw error;
    }
  }
  return result;
}

// Export the helpers used by the app backend and tests.
module.exports = {storeReportRecipients};
