import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/local_database.dart';
import '../services/local_data_session.dart';
import '../services/store_session.dart';
import '../widgets/inventory_ui.dart';

class LocalDatabaseScreen extends StatefulWidget {
  const LocalDatabaseScreen({
    super.key,
    this.database,
    this.scope,
    this.storeName,
  });
  final LocalDatabase? database;
  final LocalScope? scope;
  final String? storeName;
  @override
  State<LocalDatabaseScreen> createState() => _LocalDatabaseScreenState();
}

class _LocalDatabaseScreenState extends State<LocalDatabaseScreen> {
  late final database = widget.database ?? LocalDatabase.instance;
  late final scope = widget.scope ?? LocalDataSession.instance.scope;
  late final storeName =
      widget.storeName ?? StoreSession.instance.store?.name ?? 'Selected store';
  late final changes = Listenable.merge([database, StoreSession.instance]);
  Future<List<LocalTableSummary>>? tables;
  Future<LocalTablePage>? rows;
  LocalTable? table;
  Map<String, Object?>? record;
  List<String> columns = [];
  bool get allowed =>
      scope != null &&
      database.owns(scope!) &&
      (widget.scope != null || LocalDataSession.instance.scope == scope);
  @override
  void initState() {
    super.initState();
    refresh();
  }

  void refresh() {
    if (!allowed) return;
    if (table == null) {
      tables = database.inspectTables(scope!);
    } else {
      rows = database.inspectTable(scope!, table!);
    }
  }

  void back() {
    if (!allowed) {
      Navigator.maybePop(context);
      return;
    }
    if (record != null) {
      setState(() => record = null);
    } else if (table != null) {
      setState(() {
        table = null;
        refresh();
      });
    } else {
      Navigator.maybePop(context);
    }
  }

  void openTable(LocalTable value) => setState(() {
    table = value;
    rows = database.inspectTable(scope!, value);
  });
  @override
  Widget build(BuildContext context) => InventoryTheme(
    child: Builder(
      builder: (context) => AnimatedBuilder(
        animation: changes,
        builder: (context, _) => PopScope(
          canPop: !allowed || table == null,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) back();
          },
          child: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  InventoryHeader(
                    title: !allowed
                        ? 'Local Database'
                        : record != null
                        ? 'Record Details'
                        : table?.label ?? 'Local Database',
                    back: true,
                    onBack: back,
                    trailing: allowed && record == null
                        ? IconButton(
                            tooltip: 'Refresh local data',
                            onPressed: () => setState(refresh),
                            icon: const Icon(
                              Icons.refresh_rounded,
                              color: InventoryColors.green,
                            ),
                          )
                        : null,
                  ),
                  Expanded(
                    child: !allowed
                        ? const _ViewerMessage(
                            icon: Icons.lock_outline_rounded,
                            text:
                                'Sign in and select a store to view its local data.',
                          )
                        : record != null
                        ? _recordDetails()
                        : table == null
                        ? _tableList()
                        : _tableRows(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _error(Object? error) => _ViewerMessage(
    icon: Icons.storage_rounded,
    text: error is StateError
        ? error.message.toString()
        : 'Could not read the local database. Please try again.',
    action: InventoryButton(
      label: 'Try Again',
      onPressed: () => setState(refresh),
    ),
  );

  Widget _tableList() => FutureBuilder<List<LocalTableSummary>>(
    future: tables,
    builder: (context, snapshot) {
      if (snapshot.hasError) return _error(snapshot.error);
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      return ListView(
        key: const ValueKey('local-table-list'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: InventoryColors.soft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.storage_rounded,
                  color: InventoryColors.green,
                  size: 28,
                ),
                const SizedBox(height: 12),
                Text(
                  storeName,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  LocalDatabase.fileName,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Read-only · This account and store\nCached stock and prices may be out of date.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: InventoryColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          for (final summary in snapshot.data!)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  key: ValueKey('local-table-${summary.table.name}'),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  title: Text(
                    summary.table.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '${summary.table.sqlName}\n${summary.count} ${summary.count == 1 ? 'record' : 'records'}',
                    style: const TextStyle(fontSize: 12, height: 1.5),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: InventoryColors.green,
                  ),
                  onTap: () => openTable(summary.table),
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _tableRows() => FutureBuilder<LocalTablePage>(
    future: rows,
    builder: (context, snapshot) {
      if (snapshot.hasError) return _error(snapshot.error);
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final result = snapshot.data!;
      return ListView(
        key: const ValueKey('local-table-rows'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(
            table!.sqlName,
            style: const TextStyle(fontSize: 12, color: InventoryColors.muted),
          ),
          const SizedBox(height: 8),
          Text(
            '${result.total} stored ${result.total == 1 ? 'record' : 'records'}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          if (result.rows.isEmpty)
            _ViewerMessage(
              icon: Icons.inbox_outlined,
              text: table == LocalTable.preferences
                  ? 'No local records for this store yet. Change a category or sort order to save view preferences.'
                  : 'No local records for this store yet. Visit its catalogue to save data.',
            ),
          for (var i = 0; i < result.rows.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  key: ValueKey('local-record-$i'),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  title: Text(
                    _title(result.rows[i]),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    _subtitle(result.rows[i]),
                    style: const TextStyle(fontSize: 12, height: 1.5),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => setState(() {
                    record = result.rows[i];
                    columns = result.columns;
                  }),
                ),
              ),
            ),
          if (result.total > 0)
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous page',
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: result.page == 0
                      ? null
                      : () => setState(() {
                          rows = database.inspectTable(
                            scope!,
                            table!,
                            page: result.page - 1,
                          );
                        }),
                ),
                Expanded(
                  child: Text(
                    'Page ${result.page + 1} of ${(result.total / result.pageSize).ceil()}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                IconButton(
                  tooltip: 'Next page',
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: !result.hasNext
                      ? null
                      : () => setState(() {
                          rows = database.inspectTable(
                            scope!,
                            table!,
                            page: result.page + 1,
                          );
                        }),
                ),
              ],
            ),
        ],
      );
    },
  );

  String _title(Map<String, Object?> row) => switch (table!) {
    LocalTable.inventory => '${row['product_name']}',
    LocalTable.categories => '${row['name']}',
    LocalTable.sync => '${row['dataset']}',
    LocalTable.preferences => '${row['view_name']}',
  };
  String _subtitle(Map<String, Object?> row) => switch (table!) {
    LocalTable.inventory =>
      '${row['batch_id']}\nStock: ${row['quantity_on_hand']} · ${row['unit_label']}',
    LocalTable.categories =>
      '${row['category_id']} · ${row['active'] == 1 ? 'Active' : 'Archived'}',
    LocalTable.sync => 'Saved ${_date(row['saved_ms'])}',
    LocalTable.preferences =>
      'Category: ${row['category_id']} · ${row['ascending'] == 1 ? 'Asc' : 'Desc'}',
  };
  String _date(Object? value) => value is int
      ? DateFormat(
          'd MMM yyyy, HH:mm:ss',
        ).format(DateTime.fromMillisecondsSinceEpoch(value))
      : '—';

  Widget _recordDetails() => ListView(
    key: const ValueKey('local-record-fields'),
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
    children: [
      Text(
        table!.sqlName,
        style: const TextStyle(fontSize: 12, color: InventoryColors.muted),
      ),
      const SizedBox(height: 12),
      for (final column in columns)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    column,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: InventoryColors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _format(record![column], column),
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                  if (column.endsWith('_ms') && record![column] is int) ...[
                    const SizedBox(height: 6),
                    Text(
                      _date(record![column]),
                      style: const TextStyle(
                        fontSize: 12,
                        color: InventoryColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
    ],
  );
  String _format(Object? value, String column) {
    if (value == null) return 'NULL';
    if (column.endsWith('_json') && value is String) {
      try {
        return const JsonEncoder.withIndent('  ').convert(jsonDecode(value));
      } catch (_) {
        /* Show the original value. */
      }
    }
    return '$value';
  }
}

class _ViewerMessage extends StatelessWidget {
  const _ViewerMessage({required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: InventoryColors.muted),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}
