import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/firestore_service.dart';
import '../widgets/stockwise_ui.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});
  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  bool busy = false;
  late final categories = FirestoreService.instance.watchCategoryRecords();
  Future<void> _edit([StoreCategory? category]) async {
    var name = category?.name ?? '';
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(category == null ? 'Add category' : 'Rename category'),
        content: TextFormField(
          initialValue: name,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(labelText: 'Category name'),
          onChanged: (v) => name = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, name),
            child: const Text('Save'),
          ),
        ],
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

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const StockWiseHeader(
            title: 'Categories',
            leading: BackCircleButton(),
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
                return ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    const Text(
                      'Organise your store’s products. Archive unused categories to hide them from new items. Existing inventory and report history are kept.',
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: busy ? null : () => _edit(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add category'),
                    ),
                    const SizedBox(height: 14),
                    if (snapshot.data!.isEmpty)
                      const Text('No categories yet. Add your first category.'),
                    ...snapshot.data!.map(
                      (category) => Card(
                        child: ListTile(
                          leading: Icon(
                            category.active
                                ? Icons.category_outlined
                                : Icons.archive_outlined,
                          ),
                          title: Text(category.name),
                          subtitle: Text(
                            category.active ? 'Active' : 'Archived',
                          ),
                          onTap: busy ? null : () => _edit(category),
                          trailing: Switch(
                            value: category.active,
                            onChanged: busy
                                ? null
                                : (v) async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
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
                                                Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Confirm'),
                                          ),
                                        ],
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
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
