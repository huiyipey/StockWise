import 'package:flutter/foundation.dart';

import '../models/app_models.dart';
import '../models/store_role.dart';

// Keep the selected shop and its current membership access.
class StoreSession extends ChangeNotifier {
  StoreSession._();

  static final StoreSession instance = StoreSession._();

  StoreInfo? _store;
  String _role = 'customer';

  // Read the selected shop.
  StoreInfo? get store => _store;
  // Read the selected shop identifier.
  String? get storeId => _store?.id;
  // Resolve Admin or Customer for the selected shop.
  String get role => _role;
  // Require active Admin access to this shop.
  bool get canManage => _role == 'admin';
  // Use the same Admin access for team management.
  bool get canManageMembers => canManage;

  // Select the shop and apply its membership role.
  void select(StoreInfo store, {String role = 'customer'}) {
    _store = store;
    _role = canonicalStoreRole(role);
    notifyListeners();
  }

  /// Re-evaluate the selected store whenever membership access changes.
  /// Memberships for another shop cannot grant access to this shop.
  bool reconcileMemberships(Iterable<StoreMembership> memberships) {
    if (_store == null) return false;
    final updatedRole = storeMembershipRole(
      _store!.id,
      memberships.map(
        (member) => (
          storeId: member.storeId,
          role: member.role,
          isActive: member.isActive,
        ),
      ),
    );
    if (updatedRole == _role) return false;
    _role = updatedRole;
    notifyListeners();
    return true;
  }

  // Clear the selected shop and administrative access.
  void clear() {
    _store = null;
    _role = 'customer';
    notifyListeners();
  }
}
