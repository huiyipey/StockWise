import 'package:flutter/foundation.dart';

import '../models/app_models.dart';
import '../models/store_role.dart';

class StoreSession extends ChangeNotifier {
  StoreSession._();

  static final StoreSession instance = StoreSession._();

  StoreInfo? _store;
  String _role = 'customer';

  StoreInfo? get store => _store;
  String? get storeId => _store?.id;
  String get role => _role;
  bool get canManage => _role == 'admin';
  bool get canManageMembers => canManage;

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

  void clear() {
    _store = null;
    _role = 'customer';
    notifyListeners();
  }
}
