import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/app_models.dart';
import 'local_database.dart';

enum CatalogueSource { saved, live, pending, unavailable }

class CatalogueStatus {
  const CatalogueStatus(this.source, {this.savedAt});
  final CatalogueSource source;
  final DateTime? savedAt;
}

class RemoteCatalogue<T> {
  const RemoteCatalogue(
    this.values, {
    required this.fromServer,
    this.pending = false,
  });
  final List<T> values;
  final bool fromServer, pending;
}

/// Only server-confirmed snapshots replace the SQLite cache. A cached empty list is a
/// valid snapshot, distinct from a store that has never been loaded on this device.
class CatalogueCache extends ChangeNotifier {
  CatalogueCache(
    this.database, {
    this.connectionGrace = const Duration(seconds: 4),
  });
  static final instance = CatalogueCache(LocalDatabase.instance);
  final LocalDatabase database;
  final Duration connectionGrace;
  final _statuses = <(LocalScope, String), CatalogueStatus>{};
  CatalogueStatus? status(LocalScope scope, [String dataset = 'inventory']) =>
      _statuses[(scope, dataset)];
  void clearStatus() {
    _statuses.clear();
    notifyListeners();
  }

  void _status(
    LocalScope scope,
    String dataset,
    CatalogueSource source,
    DateTime? savedAt,
  ) {
    if (!database.owns(scope)) return;
    _statuses[(scope, dataset)] = CatalogueStatus(source, savedAt: savedAt);
    notifyListeners();
  }

  Stream<List<InventoryBatch>> inventory(
    LocalScope scope,
    Stream<RemoteCatalogue<InventoryBatch>> remote,
  ) => _watch(
    scope,
    'inventory',
    remote,
    () => database.inventory(scope),
    (values) => database.saveInventory(scope, values),
  );
  Stream<List<StoreCategory>> categories(
    LocalScope scope,
    Stream<RemoteCatalogue<StoreCategory>> remote,
  ) => _watch(
    scope,
    'categories',
    remote,
    () => database.categories(scope),
    (values) => database.saveCategories(scope, values),
  );

  Stream<List<T>> _watch<T>(
    LocalScope scope,
    String dataset,
    Stream<RemoteCatalogue<T>> remote,
    Future<LocalSnapshot<T>?> Function() read,
    Future<void> Function(List<T>) save,
  ) {
    late StreamController<List<T>> controller;
    StreamSubscription<RemoteCatalogue<T>>? subscription;
    Timer? emptyCacheTimer;
    bool cancelled = false, hasData = false;
    DateTime? savedAt;
    Future<void> start() async {
      LocalSnapshot<T>? cached;
      try {
        cached = await read();
      } catch (_) {
        /* Ignore a damaged cache and request the server. */
      }
      if (cancelled || !database.owns(scope)) return;
      if (cached != null) {
        savedAt = cached.savedAt;
        hasData = true;
        _status(scope, dataset, CatalogueSource.saved, savedAt);
        controller.add(cached.values);
      }
      subscription = remote.listen(
        (event) {
          if (cancelled || !database.owns(scope)) return;
          // Firestore may emit an empty memory snapshot before connecting. It must
          // not erase an already saved catalogue or claim that the store is empty.
          if (!event.fromServer && !event.pending && event.values.isEmpty) {
            if (!hasData) {
              emptyCacheTimer ??= Timer(connectionGrace, () {
                if (!cancelled && !hasData && database.owns(scope)) {
                  _status(scope, dataset, CatalogueSource.unavailable, savedAt);
                  controller.addError(
                    StateError(
                      'No saved catalogue. Connect to load this store.',
                    ),
                  );
                }
              });
            }
            return;
          }
          hasData = true;
          emptyCacheTimer?.cancel();
          if (event.fromServer && !event.pending) {
            savedAt = DateTime.now();
            unawaited(save(event.values).catchError((Object _) {}));
          }
          _status(
            scope,
            dataset,
            event.pending
                ? CatalogueSource.pending
                : event.fromServer
                ? CatalogueSource.live
                : CatalogueSource.saved,
            savedAt,
          );
          controller.add(event.values);
        },
        onError: (Object error, StackTrace stack) async {
          if (cancelled || !database.owns(scope)) return;
          emptyCacheTimer?.cancel();
          if (error is FirebaseException &&
              const {
                'permission-denied',
                'unauthenticated',
              }.contains(error.code)) {
            await database.removeStore(scope);
            if (cancelled || !database.owns(scope)) return;
            _status(scope, dataset, CatalogueSource.unavailable, null);
            controller.addError(error, stack);
            await controller.close();
          } else if (hasData) {
            _status(scope, dataset, CatalogueSource.saved, savedAt);
          } else {
            _status(scope, dataset, CatalogueSource.unavailable, null);
            controller.addError(error, stack);
          }
        },
        onDone: () {
          emptyCacheTimer?.cancel();
          if (!cancelled) controller.close();
        },
      );
    }

    controller = StreamController<List<T>>(
      onListen: start,
      onCancel: () async {
        cancelled = true;
        emptyCacheTimer?.cancel();
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }
}
