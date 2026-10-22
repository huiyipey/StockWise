// Missing preferences retain the existing default-on behavior.
function wantsReportEmail(preferences) {
  return preferences?.reportEmails !== false;
}
module.exports = {wantsReportEmail};
