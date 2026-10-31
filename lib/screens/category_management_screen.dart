import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/firestore_service.dart';
import '../widgets/inventory_ui.dart';

class CategoryManagementScreen extends StatefulWidget {
  final Stream<List<StoreCategory>>? categoryStream;
  final Future<void> Function(List<StoreCategory>)? orderSaver;
  final Future<void> Function(String name, String? id, bool active)?
  categorySaver;

  const CategoryManagementScreen({
    super.key,
    this.categoryStream,
    this.orderSaver,
    this.categorySaver,
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
    final form = GlobalKey<FormState>();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => InventoryTheme(
        child: AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          title: Text(
            category == null ? 'Add category' : 'Rename category',
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 350,
            child: Form(
              key: form,
              child: TextFormField(
                initialValue: name,
                autofocus: true,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'Category name'),
                style: const TextStyle(fontSize: 13),
                onChanged: (v) => name = v,
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  return trimmed.isEmpty ||
                          trimmed.length > 60 ||
                          trimmed == '.' ||
                          trimmed == '..'
                      ? 'Enter a name using 1-60 characters.'
                      : null;
                },
              ),
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
                    height: 46,
                    onPressed: () {
                      if (form.currentState!.validate()) {
                        Navigator.pop(context, name.trim());
                      }
                    },
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
      () => _saveCategory(value, category?.id, category?.active ?? true),
    );
  }

  Future<void> _saveCategory(String name, String? id, bool active) =>
      widget.categorySaver?.call(name, id, active) ??
      FirestoreService.instance.saveCategory(name, id: id, active: active);

  Future<void> _save(
    Future<void> Function() operation, {
    String? failureMessage,
  }) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await operation();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          inventoryFeedback(
            failureMessage ??
                (e is StateError
                    ? e.message.toString()
                    : e is ArgumentError
                    ? '${e.message}'
                    : 'Could not save the category. Please try again.'),
            error: true,
          ),
        );
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
      failureMessage:
          'Could not save the category order. The previous order has been restored.',
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
                        child: InventoryEmpty(
                          title: 'Could not load categories',
                          body: 'Please reopen this page.',
                          icon: Icons.error_outline_rounded,
                        ),
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
                            height: 46,
                            busy: busy,
                          ),
                          const SizedBox(height: 14),
                          if (items.isEmpty)
                            const InventoryEmpty(
                              title: 'No categories yet',
                              body: 'Add your first category.',
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
                                                insetPadding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 20,
                                                      vertical: 24,
                                                    ),
                                                title: Text(
                                                  v
                                                      ? 'Restore category?'
                                                      : 'Archive category?',
                                                ),
                                                content: const Text(
                                                  'Existing products and past reports will be preserved.',
                                                ),
                                                actionsPadding:
                                                    const EdgeInsets.fromLTRB(
                                                      20,
                                                      8,
                                                      20,
                                                      22,
                                                    ),
                                                actions: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: InventoryButton(
                                                          label: 'Cancel',
                                                          soft: true,
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                context,
                                                                false,
                                                              ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 14),
                                                      Expanded(
                                                        child: InventoryButton(
                                                          label: 'Confirm',
                                                          height: 46,
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                context,
                                                                true,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                          if (confirmed == true && mounted) {
                                            await _save(
                                              () => _saveCategory(
                                                category.name,
                                                category.id,
                                                v,
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
