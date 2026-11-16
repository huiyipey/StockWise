import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../models/barcode_product.dart';
import '../models/category_label.dart';
import '../services/firestore_service.dart';
import '../services/inventory_catalogue_service.dart';
import '../services/store_session.dart';
import '../widgets/inventory_ui.dart';
import '../widgets/profile_ui.dart';
import '../widgets/stockwise_ui.dart';
import 'edit_inventory_batch_screen.dart';

// Browse the same saved products used by Find saved product.
class InventoryBatchesScreen extends StatefulWidget {
  const InventoryBatchesScreen({
    super.key,
    this.productStream,
    this.categoryStream,
    this.onDelete,
    this.onSave,
  });
  final Stream<List<BarcodeProduct>>? productStream;
  final Stream<List<StoreCategory>>? categoryStream;
  final Future<void> Function(BarcodeProduct)? onDelete;
  final Future<void> Function(InventoryCatalogueDraft)? onSave;

  @override
  State<InventoryBatchesScreen> createState() => _InventoryBatchesScreenState();
}

class _InventoryBatchesScreenState extends State<InventoryBatchesScreen> {
  final search = TextEditingController();
  String query = '', category = 'all';
  bool deleting = false;
  List<StoreCategory> categoryRecords = [];
  late final storeId = StoreSession.instance.storeId;
  late final products =
      widget.productStream ??
      InventoryCatalogueService.instance.watchProducts();
  late final categories =
      widget.categoryStream ?? FirestoreService.instance.watchCategoryRecords();

  bool get allowed =>
      StoreSession.instance.canManage &&
      StoreSession.instance.storeId == storeId;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => InventoryTheme(
    child: Builder(
      builder: (context) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              InventoryHeader(
                title: 'Inventory Batches',
                back: true,
                onBack: () => Navigator.maybePop(context),
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: StoreSession.instance,
                  builder: (context, _) => !allowed
                      ? const Center(
                          child: InventoryEmpty(title: 'Admin access required'),
                        )
                      : StreamBuilder<List<StoreCategory>>(
                          stream: categories,
                          builder: (context, categorySnapshot) =>
                              StreamBuilder<List<BarcodeProduct>>(
                                stream: products,
                                builder: (context, snapshot) {
                                  if (snapshot.hasError ||
                                      categorySnapshot.hasError) {
                                    return const Center(
                                      child: InventoryEmpty(
                                        title: 'Could not load saved products',
                                        body:
                                            'Check your connection and reopen this page.',
                                        icon: Icons.error_outline_rounded,
                                      ),
                                    );
                                  }
                                  if (!snapshot.hasData ||
                                      !categorySnapshot.hasData) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  final all = snapshot.data!;
                                  categoryRecords = categorySnapshot.data!;
                                  final ids = all
                                      .map((p) => p.categoryId)
                                      .toSet();
                                  final selected = ids.contains(category)
                                      ? category
                                      : 'all';
                                  final choices = {
                                    'all': 'All Categories',
                                    for (final id in ids)
                                      id: inventoryCategoryName(
                                        id,
                                        categorySnapshot.data!,
                                      ),
                                  };
                                  final term = query.trim().toLowerCase();
                                  final visible =
                                      all
                                          .where(
                                            (product) =>
                                                (selected == 'all' ||
                                                    selected ==
                                                        product.categoryId) &&
                                                (product.name
                                                        .toLowerCase()
                                                        .contains(term) ||
                                                    product.barcode
                                                        .toLowerCase()
                                                        .contains(term)),
                                          )
                                          .toList()
                                        ..sort(
                                          (a, b) => a.name
                                              .toLowerCase()
                                              .compareTo(b.name.toLowerCase()),
                                        );
                                  return ListView(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      4,
                                      20,
                                      24,
                                    ),
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: TextField(
                                          key: const ValueKey(
                                            'catalogue-search',
                                          ),
                                          controller: search,
                                          textAlignVertical:
                                              TextAlignVertical.center,
                                          style: const TextStyle(fontSize: 13),
                                          decoration: const InputDecoration(
                                            hintText: 'Search name or barcode',
                                            floatingLabelBehavior:
                                                FloatingLabelBehavior.never,
                                            prefixIcon: Icon(
                                              Icons.search_rounded,
                                              size: 20,
                                            ),
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 14,
                                                ),
                                          ),
                                          onChanged: (value) =>
                                              setState(() => query = value),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: InventoryChoiceField(
                                          key: const ValueKey(
                                            'catalogue-category-filter',
                                          ),
                                          label: 'Category',
                                          value: selected,
                                          choices: choices,
                                          onChanged: (value) =>
                                              setState(() => category = value),
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      const Text(
                                        'Saved Products',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      if (visible.isEmpty)
                                        InventoryEmpty(
                                          title: all.isEmpty
                                              ? 'No saved products yet'
                                              : 'No products match',
                                          body: all.isEmpty
                                              ? 'Products are saved when you add inventory.'
                                              : null,
                                        )
                                      else
                                        for (final product in visible)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 10,
                                            ),
                                            child: Dismissible(
                                              key: ValueKey(
                                                'catalogue-product-${product.id}',
                                              ),
                                              direction: deleting
                                                  ? DismissDirection.none
                                                  : DismissDirection.startToEnd,
                                              background: Container(
                                                alignment: Alignment.centerLeft,
                                                padding: const EdgeInsets.all(
                                                  20,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: InventoryColors.error,
                                                  borderRadius:
                                                      BorderRadius.circular(18),
                                                ),
                                                child: const Icon(
                                                  Icons.delete_outline_rounded,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              confirmDismiss: (_) =>
                                                  _delete(product),
                                              child: _card(
                                                product,
                                                inventoryCategoryName(
                                                  product.categoryId,
                                                  categorySnapshot.data!,
                                                ),
                                              ),
                                            ),
                                          ),
                                    ],
                                  );
                                },
                              ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _card(BarcodeProduct product, String categoryName) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: deleting ? null : () => _edit(product),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProductArtwork(
              size: 76,
              imagePath: product.imagePath,
              enlargeOnTap: true,
              imageLabel: product.name,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${categoryTitleCase(categoryName)} / ${product.unitLabel}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: InventoryColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Barcode: ${product.barcode.isEmpty ? 'Not recorded' : product.barcode}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: InventoryColors.muted,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'RM ${(product.basePriceCents / 100).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 15,
                      color: InventoryColors.green,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: ValueKey('edit-catalogue-${product.id}'),
              tooltip: 'Edit inventory batch',
              onPressed: deleting ? null : () => _edit(product),
              style: IconButton.styleFrom(
                backgroundColor: InventoryColors.soft,
                foregroundColor: InventoryColors.green,
                minimumSize: const Size.square(36),
                padding: const EdgeInsets.all(8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.edit_outlined, size: 18),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _edit(BarcodeProduct product) async {
    if (!allowed) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditInventoryBatchScreen(
          product: product,
          categoryStream: widget.categoryStream == null
              ? null
              : Stream.value(categoryRecords),
          onSave: widget.onSave,
        ),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(inventoryFeedback('Inventory batch updated.'));
    }
  }

  Future<bool> _delete(BarcodeProduct product) async {
    if (!allowed || deleting) return false;
    final confirmed = await showProfileConfirmation(
      context: context,
      title: 'Delete inventory batch?',
      message:
          'Remove ${product.name} from saved products? Existing stock, orders and history will be kept.',
      action: 'Delete',
      cancel: 'Cancel',
      danger: true,
    );
    if (!confirmed || !mounted || !allowed) return false;
    setState(() => deleting = true);
    try {
      await (widget.onDelete ??
          InventoryCatalogueService.instance.deleteProduct)(product);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(inventoryFeedback('Saved inventory batch deleted.'));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          inventoryFeedback(
            e is StateError
                ? e.message
                : 'Could not delete this saved product. Try again.',
            error: true,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => deleting = false);
    }
    // The product stream removes the row after the deletion succeeds.
    return false;
  }
}
