// Missing preferences retain the existing default-on behavior.
function wantsReportEmail(preferences) {
  return preferences?.reportEmails !== false;
}
// Export the helpers used by the app backend and tests.
module.exports = {wantsReportEmail};
