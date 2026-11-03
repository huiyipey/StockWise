import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/app_models.dart';

@immutable
class LocalScope {
  const LocalScope(this.userId, this.storeId);
  final String userId, storeId;
  List<String> get arguments => [userId, storeId];
  @override
  bool operator ==(Object other) =>
      other is LocalScope && userId == other.userId && storeId == other.storeId;
  @override
  int get hashCode => Object.hash(userId, storeId);
}

class LocalSnapshot<T> {
  const LocalSnapshot(this.values, this.savedAt);
  final List<T> values;
  final DateTime savedAt;
}

class CatalogueViewPreferences {
  const CatalogueViewPreferences({
    this.category = 'all',
    this.ascending = true,
  });
  final String category;
  final bool ascending;
}

enum LocalTable {
  inventory('inventory_cache', 'Inventory', 'batch_id'),
  categories('category_cache', 'Categories', 'sort_order, category_id'),
  sync('cache_sync', 'Cache Updates', 'dataset'),
  preferences('view_preferences', 'View Preferences', 'view_name');

  const LocalTable(this.sqlName, this.label, this.orderBy);
  final String sqlName, label, orderBy;
}

class LocalTableSummary {
  const LocalTableSummary(this.table, this.count);
  final LocalTable table;
  final int count;
}

class LocalTablePage {
  const LocalTablePage({
    required this.table,
    required this.columns,
    required this.rows,
    required this.total,
    required this.page,
    required this.pageSize,
  });
  final LocalTable table;
  final List<String> columns;
  final List<Map<String, Object?>> rows;
  final int total, page, pageSize;
  bool get hasNext => (page + 1) * pageSize < total;
}

/// Disposable read caches. Firebase remains authoritative for every business write.
class LocalDatabase extends ChangeNotifier {
  LocalDatabase({this.factory, this.path, DateTime Function()? now})
    : _now = now ?? DateTime.now;
  static final instance = LocalDatabase();
  static const fileName = 'stockwise_local.db';
  static const schemaVersion = 1;
  static const inventoryLifetime = Duration(days: 1);
  static const categoryLifetime = Duration(days: 7);
  static const preferenceLifetime = Duration(days: 30);
  final DatabaseFactory? factory;
  final String? path;
  final DateTime Function() _now;
  Future<Database>? _opening;
  String? _userId;
  String? get userId => _userId;
  bool get supported =>
      factory != null ||
      (!kIsWeb &&
          const {
            TargetPlatform.android,
            TargetPlatform.iOS,
            TargetPlatform.macOS,
          }.contains(defaultTargetPlatform));
  bool owns(LocalScope scope) =>
      scope.userId.isNotEmpty && scope.userId == _userId;

  Future<Database> get _database => _opening ??= _open();
  Future<Database> _open() async {
    final engine = factory ?? databaseFactory;
    final location = path ?? '${await engine.getDatabasesPath()}/$fileName';
    return engine.openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: (db, version) async {
          await db.execute(
            '''CREATE TABLE inventory_cache (
          user_id TEXT NOT NULL, store_id TEXT NOT NULL, batch_id TEXT NOT NULL,
          product_id TEXT NOT NULL, product_name TEXT NOT NULL, category_id TEXT NOT NULL,
          barcode TEXT, image_path TEXT, unit_label TEXT NOT NULL, expiry_ms INTEGER NOT NULL,
          quantity_on_hand INTEGER NOT NULL, quantity_reserved INTEGER NOT NULL,
          base_price_cents INTEGER NOT NULL, promotion_enabled INTEGER NOT NULL,
          promotion_price_cents INTEGER, promotion_json TEXT, notify_on_expiry INTEGER NOT NULL,
          status TEXT NOT NULL, received_ms INTEGER, total_shelf_life_days INTEGER,
          saved_ms INTEGER NOT NULL, PRIMARY KEY (user_id, store_id, batch_id))''',
          );
          await db.execute(
            'CREATE INDEX inventory_expiry ON inventory_cache(user_id, store_id, expiry_ms)',
          );
          await db.execute(
            '''CREATE TABLE category_cache (
          user_id TEXT NOT NULL, store_id TEXT NOT NULL, category_id TEXT NOT NULL,
          name TEXT NOT NULL, active INTEGER NOT NULL, sort_order INTEGER NOT NULL,
          saved_ms INTEGER NOT NULL, PRIMARY KEY (user_id, store_id, category_id))''',
          );
          await db.execute(
            '''CREATE TABLE cache_sync (
          user_id TEXT NOT NULL, store_id TEXT NOT NULL, dataset TEXT NOT NULL,
          saved_ms INTEGER NOT NULL, PRIMARY KEY (user_id, store_id, dataset))''',
          );
          await db.execute('''CREATE TABLE view_preferences (
          user_id TEXT NOT NULL, store_id TEXT NOT NULL, view_name TEXT NOT NULL,
          category_id TEXT NOT NULL, ascending INTEGER NOT NULL, saved_ms INTEGER NOT NULL,
          PRIMARY KEY (user_id, store_id, view_name))''');
        },
      ),
    );
  }

  /// Invalidate access synchronously so late listeners cannot repopulate another account's data.
  Future<void> activateAccount(String? userId) async {
    final previous = _userId;
    _userId = userId;
    if (previous != userId) notifyListeners();
    if (!supported) return;
    try {
      final db = await _database;
      await db.transaction((tx) async {
        for (final table in [
          'inventory_cache',
          'category_cache',
          'cache_sync',
          'view_preferences',
        ]) {
          if (userId == null || previous != null && previous != userId) {
            await tx.delete(table);
          } else {
            await tx.delete(table, where: 'user_id <> ?', whereArgs: [userId]);
          }
        }
        await _prune(tx);
      });
    } catch (_) {
      // A cache failure must not prevent online sign-in or access to the server.
    }
  }

  Future<void> _prune(DatabaseExecutor db) async {
    final now = _now();
    for (final entry in {
      'inventory_cache': inventoryLifetime,
      'category_cache': categoryLifetime,
      'view_preferences': preferenceLifetime,
    }.entries) {
      await db.delete(
        entry.key,
        where: 'saved_ms < ?',
        whereArgs: [now.subtract(entry.value).millisecondsSinceEpoch],
      );
    }
    for (final entry in {
      'inventory': inventoryLifetime,
      'categories': categoryLifetime,
    }.entries) {
      await db.delete(
        'cache_sync',
        where: 'dataset = ? AND saved_ms < ?',
        whereArgs: [
          entry.key,
          now.subtract(entry.value).millisecondsSinceEpoch,
        ],
      );
    }
  }

  Future<void> _replace(
    LocalScope scope,
    String table,
    String dataset,
    List<Map<String, Object?>> rows,
  ) async {
    if (!supported || !owns(scope)) return;
    try {
      final db = await _database;
      await db.transaction((tx) async {
        if (!owns(scope)) return;
        final saved = _now().millisecondsSinceEpoch;
        await tx.delete(
          table,
          where: 'user_id = ? AND store_id = ?',
          whereArgs: scope.arguments,
        );
        final batch = tx.batch();
        for (final row in rows) {
          batch.insert(table, {
            'user_id': scope.userId,
            'store_id': scope.storeId,
            ...row,
            'saved_ms': saved,
          });
        }
        batch.insert('cache_sync', {
          'user_id': scope.userId,
          'store_id': scope.storeId,
          'dataset': dataset,
          'saved_ms': saved,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await batch.commit(noResult: true);
      });
    } catch (_) {
      /* A failed cache write never changes server results. */
    }
  }

  Future<void> saveInventory(LocalScope scope, List<InventoryBatch> values) =>
      _replace(
        scope,
        'inventory_cache',
        'inventory',
        values
            .map(
              (b) => <String, Object?>{
                'batch_id': b.id,
                'product_id': b.productId,
                'product_name': b.productName,
                'category_id': b.categoryId,
                'barcode': b.barcode,
                'image_path': b.imagePath,
                'unit_label': b.unitLabel,
                'expiry_ms': b.expiryAt.millisecondsSinceEpoch,
                'quantity_on_hand': b.quantityOnHand,
                'quantity_reserved': b.quantityReserved,
                'base_price_cents': b.basePriceCents,
                'promotion_enabled': b.promotionEnabled ? 1 : 0,
                'promotion_price_cents': b.promotionPriceCents,
                'promotion_json': b.promotion == null
                    ? null
                    : jsonEncode(b.promotion),
                'notify_on_expiry': b.notifyOnExpiry ? 1 : 0,
                'status': b.status,
                'received_ms': b.receivedAt?.millisecondsSinceEpoch,
                'total_shelf_life_days': b.totalShelfLifeDays,
              },
            )
            .toList(),
      );

  Future<void> saveCategories(LocalScope scope, List<StoreCategory> values) =>
      _replace(
        scope,
        'category_cache',
        'categories',
        values
            .map(
              (c) => <String, Object?>{
                'category_id': c.id,
                'name': c.name,
                'active': c.active ? 1 : 0,
                'sort_order': c.sortOrder,
              },
            )
            .toList(),
      );

  Future<LocalSnapshot<Map<String, Object?>>?> _read(
    LocalScope scope,
    String table,
    String dataset,
    Duration lifetime,
  ) async {
    if (!supported || !owns(scope)) return null;
    try {
      final db = await _database;
      return await db.transaction((tx) async {
        if (!owns(scope)) return null;
        final sync = await tx.query(
          'cache_sync',
          where: 'user_id = ? AND store_id = ? AND dataset = ?',
          whereArgs: [...scope.arguments, dataset],
        );
        if (sync.isEmpty) return null;
        final saved = DateTime.fromMillisecondsSinceEpoch(
          sync.single['saved_ms'] as int,
        );
        if (_now().difference(saved) >= lifetime || saved.isAfter(_now())) {
          return null;
        }
        final rows = await tx.query(
          table,
          where: 'user_id = ? AND store_id = ?',
          whereArgs: scope.arguments,
        );
        return owns(scope) ? LocalSnapshot(rows, saved) : null;
      });
    } catch (_) {
      return null;
    }
  }

  Future<LocalSnapshot<InventoryBatch>?> inventory(LocalScope scope) async {
    final saved = await _read(
      scope,
      'inventory_cache',
      'inventory',
      inventoryLifetime,
    );
    if (saved == null) return null;
    final values =
        saved.values
            .map(
              (r) => InventoryBatch(
                id: r['batch_id'] as String,
                productId: r['product_id'] as String,
                productName: r['product_name'] as String,
                categoryId: r['category_id'] as String,
                barcode: r['barcode'] as String?,
                imagePath: r['image_path'] as String?,
                unitLabel: r['unit_label'] as String,
                expiryAt: DateTime.fromMillisecondsSinceEpoch(
                  r['expiry_ms'] as int,
                ),
                quantityOnHand: r['quantity_on_hand'] as int,
                quantityReserved: r['quantity_reserved'] as int,
                basePriceCents: r['base_price_cents'] as int,
                promotionEnabled: r['promotion_enabled'] == 1,
                promotionPriceCents: r['promotion_price_cents'] as int?,
                promotion: r['promotion_json'] == null
                    ? null
                    : Map<String, dynamic>.from(
                        jsonDecode(r['promotion_json'] as String) as Map,
                      ),
                notifyOnExpiry: r['notify_on_expiry'] == 1,
                status: r['status'] as String,
                receivedAt: r['received_ms'] == null
                    ? null
                    : DateTime.fromMillisecondsSinceEpoch(
                        r['received_ms'] as int,
                      ),
                totalShelfLifeDays: r['total_shelf_life_days'] as int?,
              ),
            )
            .toList()
          ..sort((a, b) {
            final order = a.expiryAt.compareTo(b.expiryAt);
            return order == 0 ? a.id.compareTo(b.id) : order;
          });
    return LocalSnapshot(values, saved.savedAt);
  }

  Future<LocalSnapshot<StoreCategory>?> categories(LocalScope scope) async {
    final saved = await _read(
      scope,
      'category_cache',
      'categories',
      categoryLifetime,
    );
    if (saved == null) return null;
    final values =
        saved.values
            .map(
              (r) => StoreCategory(
                id: r['category_id'] as String,
                name: r['name'] as String,
                active: r['active'] == 1,
                sortOrder: r['sort_order'] as int,
              ),
            )
            .toList()
          ..sort(StoreCategory.compare);
    return LocalSnapshot(values, saved.savedAt);
  }

  Future<void> saveView(
    LocalScope scope,
    String view,
    CatalogueViewPreferences value,
  ) async {
    if (!supported ||
        !owns(scope) ||
        !const {'shop', 'inventory', 'overview'}.contains(view)) {
      return;
    }
    try {
      final db = await _database;
      await db.transaction((tx) async {
        if (!owns(scope)) return;
        await tx.insert('view_preferences', {
          'user_id': scope.userId,
          'store_id': scope.storeId,
          'view_name': view,
          'category_id': value.category,
          'ascending': value.ascending ? 1 : 0,
          'saved_ms': _now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });
    } catch (_) {
      /* Preferences are optional, never a prerequisite for using a screen. */
    }
  }

  Future<CatalogueViewPreferences?> view(LocalScope scope, String view) async {
    if (!supported || !owns(scope)) return null;
    try {
      final db = await _database;
      final rows = await db.query(
        'view_preferences',
        where:
            'user_id = ? AND store_id = ? AND view_name = ? AND saved_ms > ?',
        whereArgs: [
          ...scope.arguments,
          view,
          _now().subtract(preferenceLifetime).millisecondsSinceEpoch,
        ],
      );
      if (!owns(scope) || rows.isEmpty) return null;
      return CatalogueViewPreferences(
        category: rows.single['category_id'] as String,
        ascending: rows.single['ascending'] == 1,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> removeStore(LocalScope scope) async {
    if (!supported || !owns(scope)) return;
    try {
      final db = await _database;
      await db.transaction((tx) async {
        for (final table in [
          'inventory_cache',
          'category_cache',
          'cache_sync',
          'view_preferences',
        ]) {
          await tx.delete(
            table,
            where: 'user_id = ? AND store_id = ?',
            whereArgs: scope.arguments,
          );
        }
      });
    } catch (_) {
      /* Retention and account isolation still apply if storage is unavailable. */
    }
  }

  void _requireInspectionAccess(LocalScope scope) {
    if (!owns(scope)) {
      throw StateError('Sign in to view this account’s local data.');
    }
    if (!supported) {
      throw StateError(
        'The SQLite viewer is available on Android, iOS and macOS.',
      );
    }
  }

  Future<List<LocalTableSummary>> inspectTables(LocalScope scope) async {
    _requireInspectionAccess(scope);
    final db = await _database;
    final result = await db.transaction((tx) async {
      _requireInspectionAccess(scope);
      final summaries = <LocalTableSummary>[];
      for (final table in LocalTable.values) {
        final count = Sqflite.firstIntValue(
          await tx.rawQuery(
            'SELECT COUNT(*) FROM ${table.sqlName} WHERE user_id = ? AND store_id = ?',
            scope.arguments,
          ),
        );
        summaries.add(LocalTableSummary(table, count ?? 0));
      }
      return summaries;
    });
    _requireInspectionAccess(scope);
    return result;
  }

  Future<LocalTablePage> inspectTable(
    LocalScope scope,
    LocalTable table, {
    int page = 0,
    int pageSize = 20,
  }) async {
    _requireInspectionAccess(scope);
    if (page < 0 || pageSize < 1 || pageSize > 100) {
      throw RangeError('Invalid page or page size.');
    }
    final db = await _database;
    final result = await db.transaction((tx) async {
      _requireInspectionAccess(scope);
      final total =
          Sqflite.firstIntValue(
            await tx.rawQuery(
              'SELECT COUNT(*) FROM ${table.sqlName} WHERE user_id = ? AND store_id = ?',
              scope.arguments,
            ),
          ) ??
          0;
      final lastPage = total == 0 ? 0 : (total - 1) ~/ pageSize;
      final currentPage = page.clamp(0, lastPage);
      final schema = await tx.rawQuery('PRAGMA table_info(${table.sqlName})');
      final rows = await tx.query(
        table.sqlName,
        where: 'user_id = ? AND store_id = ?',
        whereArgs: scope.arguments,
        orderBy: table.orderBy,
        limit: pageSize,
        offset: currentPage * pageSize,
      );
      return LocalTablePage(
        table: table,
        columns: schema.map((r) => r['name'] as String).toList(),
        rows: rows,
        total: total,
        page: currentPage,
        pageSize: pageSize,
      );
    });
    _requireInspectionAccess(scope);
    return result;
  }

  Future<void> close() async {
    final opening = _opening;
    _opening = null;
    if (opening != null) await (await opening).close();
  }
}
