import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/firestore_service.dart';
import '../services/store_session.dart';
import '../services/inventory_list.dart';
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

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key, this.inventoryStream, this.categoryStream});
  final Stream<List<InventoryBatch>>? inventoryStream;
  final Stream<List<StoreCategory>>? categoryStream;
  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final searchController = TextEditingController();
  String query = '', category = 'all';
  DateTimeRange? expiryRange;
  bool expiryAscending = true;
  late final inventory =
      widget.inventoryStream ?? FirestoreService.instance.watchInventory();
  late final categories =
      widget.categoryStream ?? FirestoreService.instance.watchCategoryRecords();
  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) => InventoryTheme(
    child: Builder(
      builder: (context) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              InventoryHeader(
                title: 'Inventory',
                storeName: StoreSession.instance.store?.name ?? 'StockWise',
              ),
              Expanded(
                child: StreamBuilder<List<StoreCategory>>(
                  stream: categories,
                  builder: (context, records) =>
                      StreamBuilder<List<InventoryBatch>>(
                        stream: inventory,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const Center(
                              child: InventoryEmpty(
                                icon: Icons.error_outline_rounded,
                                title: 'Could not load inventory',
                                body:
                                    'Check your connection and reopen this page.',
                              ),
                            );
                          }
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final ids =
                              snapshot.data!
                                  .map((item) => item.categoryId)
                                  .toSet()
                                  .toList()
                                ..sort();
                          final today = DateTime.now();
                          final items =
                              snapshot.data!
                                  .where(
                                    (item) =>
                                        matchesInventorySearch(item, query) &&
                                        (category == 'all' ||
                                            item.categoryId == category) &&
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
                              InventoryFilters(
                                ids: ids,
                                records: records.data ?? [],
                                category: category,
                                onCategory: (value) =>
                                    setState(() => category = value),
                                range: expiryRange,
                                onDate: () => _pickExpiryRange(context),
                                onClearDate: () =>
                                    setState(() => expiryRange = null),
                                ascending: expiryAscending,
                                onSort: () => setState(
                                  () => expiryAscending = !expiryAscending,
                                ),
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
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  );
                                  if (constraints.maxWidth < 300 ||
                                      MediaQuery.textScalerOf(
                                            context,
                                          ).scale(12) >
                                          16) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                const InventoryEmpty(
                                  title: 'No inventory found',
                                )
                              else
                                for (final item in items)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
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
          tooltip: 'Add item',
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

  bool _inRange(DateTime date) {
    final range = expiryRange;
    if (range == null) return true;
    final day = DateUtils.dateOnly(date);
    return !day.isBefore(DateUtils.dateOnly(range.start)) &&
        !day.isAfter(DateUtils.dateOnly(range.end));
  }

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
        label: 'Items',
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
