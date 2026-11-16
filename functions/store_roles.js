// Store membership is the authority. Legacy team roles are aliases during the
// transition; new membership documents only write the canonical `admin` role.
const ADMIN_ROLE_ALIASES = Object.freeze(['admin', 'owner', 'manager', 'staff']);

// Recognize Admin and supported legacy administrative roles.
function isAdminRole(role) {
  return ADMIN_ROLE_ALIASES.includes(role);
}

// Require both an administrative role and active membership.
function isActiveStoreAdmin(member) {
  return member?.isActive === true && isAdminRole(member.role);
}

// Export the helpers used by the app backend and tests.
module.exports = {ADMIN_ROLE_ALIASES, isAdminRole, isActiveStoreAdmin};
