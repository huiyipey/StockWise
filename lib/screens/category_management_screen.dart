import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/firestore_service.dart';
import '../widgets/inventory_ui.dart';

class CategoryManagementScreen extends StatefulWidget {
  final Stream<List<StoreCategory>>? categoryStream;
  final Future<void> Function(List<StoreCategory>)? orderSaver;

  const CategoryManagementScreen({
    super.key,
    this.categoryStream,
    this.orderSaver,
  });
  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  bool busy = false;
  List<StoreCategory>? pendingOrder;
  late final categories =
      widget.categoryStream ?? FirestoreService.instance.watchCategoryRecords();
  Future<void> _edit([StoreCategory? category]) async {
    var name = category?.name ?? '';
    final value = await showDialog<String>(
      context: context,
      builder: (context) => InventoryTheme(
        child: AlertDialog(
          title: Text(
            category == null ? 'Add category' : 'Rename category',
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 350,
            child: TextFormField(
              initialValue: name,
              autofocus: true,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'Category name'),
              style: const TextStyle(fontSize: 13),
              onChanged: (v) => name = v,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
          actions: [
            Row(
              children: [
                Expanded(
                  child: InventoryButton(
                    label: 'Cancel',
                    soft: true,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: InventoryButton(
                    label: 'Save',
                    onPressed: () => Navigator.pop(context, name),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (value == null || !mounted) return;
    await _save(
      () => FirestoreService.instance.saveCategory(
        value,
        id: category?.id,
        active: category?.active ?? true,
      ),
    );
  }

  Future<void> _save(Future<void> Function() operation) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await operation();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _reorder(
    List<StoreCategory> items,
    int oldIndex,
    int newIndex,
  ) async {
    if (busy) return;
    if (oldIndex == newIndex) return;
    final reordered = List<StoreCategory>.of(items);
    reordered.insert(newIndex, reordered.removeAt(oldIndex));
    setState(() => pendingOrder = reordered);
    await _save(
      () => (widget.orderSaver ?? FirestoreService.instance.reorderCategories)(
        reordered,
      ),
    );
    if (mounted) setState(() => pendingOrder = null);
  }

  @override
  Widget build(BuildContext context) => InventoryTheme(
    child: Builder(
      builder: (context) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              InventoryHeader(
                title: 'Categories',
                back: true,
                onBack: () => Navigator.maybePop(context),
              ),
              Expanded(
                child: StreamBuilder<List<StoreCategory>>(
                  stream: categories,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Could not load categories.'),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final items = pendingOrder ?? snapshot.data!;
                    return ReorderableListView.builder(
                      padding: const EdgeInsets.all(18),
                      buildDefaultDragHandles: false,
                      onReorderItem: (oldIndex, newIndex) =>
                          _reorder(items, oldIndex, newIndex),
                      header: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Drag the handles to arrange categories. Archive unused categories to hide them from new items.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.6,
                              color: InventoryColors.muted,
                            ),
                          ),
                          const SizedBox(height: 14),
                          InventoryButton(
                            key: const ValueKey('add-category'),
                            onPressed: busy ? null : () => _edit(),
                            icon: Icons.add,
                            label: 'Add category',
                          ),
                          const SizedBox(height: 14),
                          if (items.isEmpty)
                            const Text(
                              'No categories yet. Add your first category.',
                            ),
                        ],
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final category = items[index];
                        return Card(
                          key: ValueKey(category.id),
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            minTileHeight: 76,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 15,
                            ),
                            leading: Icon(
                              category.active
                                  ? Icons.inventory_2_outlined
                                  : Icons.storefront_outlined,
                              color: category.active
                                  ? InventoryColors.green
                                  : InventoryColors.muted,
                              size: 22,
                            ),
                            title: Text(
                              category.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              category.active ? 'Active' : 'Archived',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: InventoryColors.muted,
                              ),
                            ),
                            onTap: busy ? null : () => _edit(category),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: category.active,
                                  onChanged: busy
                                      ? null
                                      : (v) async {
                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => InventoryTheme(
                                              child: AlertDialog(
                                                title: Text(
                                                  v
                                                      ? 'Restore category?'
                                                      : 'Archive category?',
                                                ),
                                                content: const Text(
                                                  'Existing products and past reports will be preserved.',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          context,
                                                          false,
                                                        ),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  FilledButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          context,
                                                          true,
                                                        ),
                                                    child: const Text(
                                                      'Confirm',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                          if (confirmed == true && mounted) {
                                            await _save(
                                              () => FirestoreService.instance
                                                  .saveCategory(
                                                    category.name,
                                                    id: category.id,
                                                    active: v,
                                                  ),
                                            );
                                          }
                                        },
                                ),
                                ReorderableDragStartListener(
                                  index: index,
                                  enabled: !busy,
                                  child: const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Tooltip(
                                      message: 'Drag to reorder category',
                                      child: Icon(Icons.drag_handle_rounded),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
