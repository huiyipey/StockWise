import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/firestore_service.dart';
import '../services/store_session.dart';
import '../services/inventory_list.dart';
import '../services/local_data_session.dart';
import '../widgets/catalogue_cache_notice.dart';
import '../widgets/glass_bottom_nav.dart';
import '../widgets/inventory_ui.dart';
import '../widgets/inventory_expiry_range.dart';
import 'add_item_screen.dart';
import 'admin_item_detail_screen.dart';
import 'barcode_scanner_screen.dart';
import 'home_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'waste_analysis_screen.dart';
import 'category_management_screen.dart';

// Search and filter the admin inventory list.
class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key, this.inventoryStream, this.categoryStream});
  final Stream<List<InventoryBatch>>? inventoryStream;
  final Stream<List<StoreCategory>>? categoryStream;
  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

// Manage the items screen values and actions.
class _ItemsScreenState extends State<ItemsScreen> {
  // Keep this component's values, selections, and request state.
  final searchController = TextEditingController();
  String query = '', category = 'all';
  DateTimeRange? expiryRange;
  bool expiryAscending = true;
  final savedView = SavedCatalogueView('inventory');
  // Set up the initial values and screen state.
  @override
  void initState() {
    super.initState();
    _restoreView();
  }

  // Restore the saved category and sort preferences.
  Future<void> _restoreView() async {
    final value = await savedView.restore();
    if (mounted && value != null) {
      setState(() {
        category = value.category;
        expiryAscending = value.ascending;
      });
    }
  }

  // Remember the current category and sort preferences.
  void _saveView() => savedView.save(category, expiryAscending);
  late final inventory =
      widget.inventoryStream ?? FirestoreService.instance.watchInventory();
  late final categories =
      widget.categoryStream ?? FirestoreService.instance.watchCategoryRecords();
  // Release controllers, timers, and subscriptions held by this component.
  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // Scan a barcode before opening or filling the item editor.
  Future<void> _scanBarcode() async {
    FocusScope.of(context).unfocus();
    final value = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (value != null && mounted) {
      setState(() {
        searchController.text = value;
        query = value;
      });
    }
  }

  // Build the items screen layout.
  @override
  Widget build(BuildContext context) => InventoryTheme(
    child: Builder(
      builder: (context) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Show the page title, shop name, and header actions.
              InventoryHeader(
                title: 'Inventory',
                storeName: StoreSession.instance.store?.name ?? 'StockWise',
              ),
              // Explain when a saved catalogue snapshot is being displayed.
              const CatalogueCacheNotice(),
              Expanded(
                // Follow category names and archive-state changes.
                child: StreamBuilder<List<StoreCategory>>(
                  stream: categories,
                  // Refresh this section when its live data changes.
                  builder: (context, records) => StreamBuilder<List<InventoryBatch>>(
                    stream: inventory,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: InventoryEmpty(
                            icon: Icons.error_outline_rounded,
                            title: 'Could not load inventory',
                            body: 'Check your connection and reopen this page.',
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final ids =
                          snapshot.data!
                              .map((item) => item.categoryId)
                              .toSet()
                              .toList()
                            ..sort();
                      final today = DateTime.now();
                      final effectiveCategory = ids.contains(category)
                          ? category
                          : 'all';
                      final items =
                          snapshot.data!
                              .where(
                                (item) =>
                                    matchesInventorySearch(item, query) &&
                                    (effectiveCategory == 'all' ||
                                        item.categoryId == effectiveCategory) &&
                                    _inRange(item.expiryAt),
                              )
                              .toList()
                            ..sort(
                              (a, b) => compareAdminInventory(
                                a,
                                b,
                                ascending: expiryAscending,
                                today: today,
                              ),
                            );
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 92),
                        children: [
                          ClipRRect(
                            key: const ValueKey('inventory-search-outline'),
                            borderRadius: BorderRadius.circular(12),
                            child: TextField(
                              controller: searchController,
                              textAlignVertical: TextAlignVertical.center,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.never,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                constraints: const BoxConstraints(
                                  minHeight: 46,
                                ),
                                hintText: 'Search name or barcode',
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  size: 18,
                                  color: InventoryColors.muted,
                                ),
                                suffixIcon: IconButton(
                                  tooltip: 'Scan barcode to search',
                                  onPressed: _scanBarcode,
                                  icon: const Icon(
                                    Icons.qr_code_scanner_rounded,
                                    color: InventoryColors.green,
                                    size: 20,
                                  ),
                                ),
                              ),
                              onChanged: (value) =>
                                  setState(() => query = value),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Apply the category, expiry, and sort filters.
                          InventoryFilters(
                            ids: ids,
                            records: records.data ?? [],
                            category: effectiveCategory,
                            onCategory: (value) {
                              setState(() => category = value);
                              _saveView();
                            },
                            range: expiryRange,
                            onDate: () => _pickExpiryRange(context),
                            onClearDate: () =>
                                setState(() => expiryRange = null),
                            ascending: expiryAscending,
                            onSort: () {
                              setState(
                                () => expiryAscending = !expiryAscending,
                              );
                              _saveView();
                            },
                          ),
                          const SizedBox(height: 14),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              const heading = Text(
                                'All Inventory',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              );
                              final manage = TextButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const CategoryManagementScreen(),
                                  ),
                                ),
                                child: const Text(
                                  'Manage categories',
                                  style: TextStyle(
                                    fontSize: 12,
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                              if (constraints.maxWidth < 300 ||
                                  MediaQuery.textScalerOf(context).scale(12) >
                                      16) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [heading, manage],
                                );
                              }
                              return Row(
                                children: [
                                  const Expanded(child: heading),
                                  manage,
                                ],
                              );
                            },
                          ),
                          if (items.isEmpty)
                            const InventoryEmpty(title: 'No inventory found')
                          else
                            for (final item in items)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Dismissible(
                                  key: ValueKey("inventory-${item.id}"),
                                  direction: DismissDirection.startToEnd,
                                  background: Container(
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: InventoryColors.error,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.white,
                                    ),
                                  ),
                                  confirmDismiss: (_) async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text("Delete Inventory?"),
                                        content: const Text(
                                          "This removes the inventory batch. Waste is recorded only if the inventory is expired and still has remaining stock.",
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text("Cancel"),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text("Delete"),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      try {
                                        await FirestoreService.instance
                                            .removeInventory(item);
                                      } catch (_) {
                                        if (context.mounted) {
                                          showInventoryOverlayFeedback(
                                            context,
                                            "Could not delete inventory. Try again.",
                                          );
                                        }
                                      }
                                    }
                                    return false;
                                  },
                                  // Show one stock batch with its expiry and quantity.
                                  child: InventoryBatchTile(
                                    enlarged: true,
                                    item: item,
                                    categoryName: inventoryCategoryName(
                                      item.categoryId,
                                      records.data ?? [],
                                    ),
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AdminItemDetailScreen(
                                          liveUpdates:
                                              widget.inventoryStream == null,
                                          item: item,
                                          categoryName: inventoryCategoryName(
                                            item.categoryId,
                                            records.data ?? [],
                                          ),
                                          onDiscarded: (message) =>
                                              showInventoryOverlayFeedback(
                                                context,
                                                message,
                                              ),
                                        ),
                                      ),
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
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(top: false, child: _bottomNav(context)),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Add Inventory',
          backgroundColor: InventoryColors.green,
          foregroundColor: Colors.white,
          elevation: 0,
          highlightElevation: 0,
          hoverElevation: 0,
          focusElevation: 0,
          shape: const CircleBorder(),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddItemScreen(
                onSaved: (message) =>
                    showInventoryOverlayFeedback(context, message),
              ),
            ),
          ),
          child: const Icon(Icons.add_rounded),
        ),
      ),
    ),
  );

  // Check whether this item matches the selected expiry range.
  bool _inRange(DateTime date) {
    final range = expiryRange;
    if (range == null) return true;
    final day = DateUtils.dateOnly(date);
    return !day.isBefore(DateUtils.dateOnly(range.start)) &&
        !day.isAfter(DateUtils.dateOnly(range.end));
  }

  // Open the expiry range selector and apply its result.
  Future<void> _pickExpiryRange(BuildContext context) async {
    final now = DateTime.now();
    final selected = await showInventoryExpiryRange(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
      initialDateRange: expiryRange,
    );
    if (selected != null && mounted) setState(() => expiryRange = selected);
  }

  // Build the navigation links for this role.
  // Show the admin navigation destinations.
  Widget _bottomNav(BuildContext context) => InventoryBottomNav(
    currentIndex: 1,
    items: [
      NavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Home',
        onTap: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        ),
      ),
      const NavItem(
        icon: Icons.inventory_2_outlined,
        activeIcon: Icons.inventory_2_rounded,
        label: 'Inventory',
      ),
      NavItem(
        icon: Icons.bar_chart_outlined,
        activeIcon: Icons.bar_chart_rounded,
        label: 'Report',
        onTap: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WasteAnalysisScreen()),
        ),
      ),
      NavItem(
        icon: Icons.shopping_cart_outlined,
        activeIcon: Icons.shopping_cart_rounded,
        label: 'Orders',
        onTap: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OrdersScreen()),
        ),
      ),
      NavItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Profile',
        onTap: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        ),
      ),
    ],
  );
}
