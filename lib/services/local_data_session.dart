import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import 'catalogue_cache.dart';
import 'local_database.dart';
import 'store_session.dart';

// Keep local storage scoped to the signed-in account and shop.
class LocalDataSession {
  LocalDataSession._();
  static final instance = LocalDataSession._();
  StreamSubscription<User?>? _subscription;
  // Return the active user and shop cache scope.
  LocalScope? get scope {
    final userId = LocalDatabase.instance.userId;
    final storeId = StoreSession.instance.storeId;
    return userId == null || storeId == null
        ? null
        : LocalScope(userId, storeId);
  }

  // Switch local cache ownership when the signed-in account changes.
  Future<void> initialize() async {
    final restoredUser = await FirebaseAuth.instance.authStateChanges().first;
    await LocalDatabase.instance.activateAccount(restoredUser?.uid);
    _subscription ??= FirebaseAuth.instance.authStateChanges().listen((user) {
      if (LocalDatabase.instance.userId != user?.uid) {
        unawaited(LocalDatabase.instance.activateAccount(user?.uid));
        CatalogueCache.instance.clearStatus();
        StoreSession.instance.clear();
      }
    });
  }
}

/// A user interaction wins over a slower preference restore from disk.
class SavedCatalogueView {
  SavedCatalogueView(this.view) : scope = LocalDataSession.instance.scope;
  final String view;
  final LocalScope? scope;
  bool _changed = false;
  // Restore the category and sort direction saved for this view.
  Future<CatalogueViewPreferences?> restore() async {
    if (scope == null) return null;
    final result = await LocalDatabase.instance.view(scope!, view);
    return _changed ? null : result;
  }

  // Save the category and sort direction for this view.
  void save(String category, bool ascending) {
    _changed = true;
    if (scope != null) {
      unawaited(
        LocalDatabase.instance.saveView(
          scope!,
          view,
          CatalogueViewPreferences(category: category, ascending: ascending),
        ),
      );
    }
  }
}
