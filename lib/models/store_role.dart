/// Roles are scoped to a store, never to the whole StockWise account.
///
/// Old memberships remain readable during migration. Missing or unfamiliar
/// values deliberately grant customer access only.
bool isStoreAdminRole(Object? role) =>
    const {'admin', 'owner', 'manager', 'staff'}.contains(role);

String canonicalStoreRole(Object? role) =>
    isStoreAdminRole(role) ? 'admin' : 'customer';

bool isAcceptableAdminInvitation(
  Map<String, dynamic>? invitation, {
  required String storeId,
  required String emailLowercase,
}) =>
    invitation?['status'] == 'pending' &&
    invitation?['role'] == 'admin' &&
    invitation?['storeId'] == storeId &&
    invitation?['emailLowercase'] == emailLowercase;

String storeMembershipRole(
  String storeId,
  Iterable<({String storeId, String role, bool isActive})> memberships,
) =>
    memberships.any(
      (member) =>
          member.storeId == storeId &&
          member.isActive &&
          isStoreAdminRole(member.role),
    )
    ? 'admin'
    : 'customer';
