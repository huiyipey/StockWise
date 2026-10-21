import 'package:flutter/foundation.dart';

import '../models/app_models.dart';

class StoreSession extends ChangeNotifier {
  StoreSession._();

  static final StoreSession instance = StoreSession._();

  StoreInfo? _store;
  String _role = 'customer';

  StoreInfo? get store => _store;
  String? get storeId => _store?.id;
  String get role => _role;
<<<<<<< HEAD
  bool get canManage =>
      const {'owner', 'admin', 'manager', 'staff'}.contains(_role);
  bool get canManageMembers => const {'owner', 'admin'}.contains(_role);
  bool get isOwner => _role == 'owner';
=======
  bool get canManage => const {'owner', 'manager', 'staff'}.contains(_role);
  bool get canManageMembers => const {'owner', 'manager'}.contains(_role);
>>>>>>> 831768e476072760b30a26d67dfa6f0d1864723f

  void select(StoreInfo store, {String role = 'customer'}) {
    _store = store;
    _role = role;
    notifyListeners();
  }

  void clear() {
    _store = null;
    _role = 'customer';
    notifyListeners();
  }
}
