import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/firestore_service.dart';
import '../services/store_session.dart';
import '../services/local_data_session.dart';
import '../widgets/catalogue_cache_notice.dart';
import '../widgets/local_database_shortcut.dart';
import 'local_database_screen.dart';
import '../widgets/glass_bottom_nav.dart';
import '../widgets/inventory_ui.dart';
import '../widgets/store_chat_button.dart';
import 'add_item_screen.dart';
import 'admin_item_detail_screen.dart';
import 'items_screen.dart';
import 'inventory_batches_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'waste_analysis_screen.dart';

// Show the admin inventory overview and expiring stock.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.inventoryStream, this.categoryStream});
  final Stream<List<InventoryBatch>>? inventoryStream;
  final Stream<List<StoreCategory>>? categoryStream;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// Manage the home screen values and actions.
class _HomeScreenState extends State<HomeScreen> {
  // Keep this component's values, selections, and request state.
  String category = 'all';
  bool expiryAscending = true;
  final savedView = SavedCatalogueView('overview');
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

  // Build the home screen layout.
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
                title: 'Overview',
                enlarged: true,
                storeName: StoreSession.instance.store?.name ?? 'StockWise',
                storeIcon: LocalDatabaseShortcut(
                  compact: true,
                  onOpen: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => const LocalDatabaseScreen(),
                      ),
                    );
                  },
                ),
                trailing: StoreSession.instance.canManageMembers
                    ? const StoreChatButton(inventoryStyle: true)
                    : null,
              ),
              // Explain when a saved catalogue snapshot is being displayed.
              const CatalogueCacheNotice(),
              Expanded(
                // Follow category names and archive-state changes.
                child: StreamBuilder<List<StoreCategory>>(
                  stream: categories,
                  builder: (context, records) =>
                      // Follow live stock quantities, prices, and expiry updates.
                      StreamBuilder<List<InventoryBatch>>(
                        stream: inventory,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const Center(
                              child: InventoryEmpty(
                                enlarged: true,
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
                          final active = snapshot.data!
                              .where(
                                (item) =>
                                    item.status == 'active' &&
                                    item.quantityOnHand > 0,
                              )
                              .toList();
                          final ids =
                              active
                                  .map((item) => item.categoryId)
                                  .toSet()
                                  .toList()
                                ..sort();
                          final now = DateTime.now();
                          final effectiveCategory = ids.contains(category)
                              ? category
                              : 'all';
                          final expiring =
                              active.where((item) {
                                final days = item.daysUntilExpiryFrom(now);
                                return days >= 0 &&
                                    days <= 30 &&
                                    (effectiveCategory == 'all' ||
                                        item.categoryId == effectiveCategory);
                              }).toList()..sort(
                                (a, b) => expiryAscending
                                    ? a.expiryAt.compareTo(b.expiryAt)
                                    : b.expiryAt.compareTo(a.expiryAt),
                              );
                          return ListView(
                            padding: const EdgeInsets.fromLTRB(20, 6, 20, 104),
                            children: [
                              _stats(active.length, expiring.length),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Expiring Stock',
                                      style: TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const ItemsScreen(),
                                      ),
                                    ),
                                    child: const Text(
                                      'View all',
                                      style: TextStyle(
                                        fontSize: 12,
                                        decoration: TextDecoration.underline,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // Apply the category, expiry, and sort filters.
                              InventoryFilters(
                                compact: true,
                                outlined: true,
                                ids: ids,
                                records: records.data ?? [],
                                category: effectiveCategory,
                                onCategory: (value) {
                                  setState(() => category = value);
                                  _saveView();
                                },
                                ascending: expiryAscending,
                                onSort: () {
                                  setState(
                                    () => expiryAscending = !expiryAscending,
                                  );
                                  _saveView();
                                },
                              ),
                              const SizedBox(height: 18),
                              if (expiring.isEmpty)
                                const Card(
                                  child: InventoryEmpty(
                                    enlarged: true,
                                    title: 'All clear for the next 30 days',
                                    body:
                                        'No stock expires in the next 30 days.',
                                    icon: Icons.check_rounded,
                                  ),
                                )
                              else
                                for (final item in expiring)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
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
                                                  navigationFontSize: 10.5,
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
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: SizedBox(
          width: MediaQuery.sizeOf(context).width - 40,
          child: InventoryButton(
            key: const ValueKey('home-add-inventory'),
            label: 'Add Inventory',
            height: 44,
            fontSize: 14,
            icon: Icons.add,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddItemScreen(
                  onSaved: (message) => showInventoryOverlayFeedback(
                    context,
                    message,
                    navigationFontSize: 10.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  // Show the active batch and expiring stock totals.
  Widget _stats(int active, int expiring) => LayoutBuilder(
    builder: (context, constraints) {
      final activeCard = Semantics(
        button: true,
        label: 'View Inventory batches',
        child: Material(
          color: InventoryColors.ink,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey('home-inventory-batches'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const InventoryBatchesScreen()),
            ),
            child: Container(
              height: 150,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: InventoryColors.ink,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ACTIVE BATCHES',
                    style: TextStyle(
                      color: Color(0xFFC9DBCA),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$active',
                        style: const TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    'Across ${StoreSession.instance.store?.name ?? 'your store'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFC9DBCA),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final expiringCard = Container(
        height: 150,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: InventoryColors.soft,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Icon(
              Icons.access_time_rounded,
              size: 24,
              color: InventoryColors.green,
            ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$expiring',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const Text(
              'Expiring in\n30 days',
              style: TextStyle(fontSize: 11.5, color: InventoryColors.muted),
            ),
          ],
        ),
      );
      if (constraints.maxWidth < 300 ||
          MediaQuery.textScalerOf(context).scale(11) > 14) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [activeCard, const SizedBox(height: 13), expiringCard],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: activeCard),
          const SizedBox(width: 13),
          Expanded(child: expiringCard),
        ],
      );
    },
  );

  // Build the navigation links for this role.
  // Show the admin navigation destinations.
  Widget _bottomNav(BuildContext context) => InventoryBottomNav(
    fontSize: 10.5,
    currentIndex: 0,
    items: [
      const NavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Home',
      ),
      NavItem(
        icon: Icons.inventory_2_outlined,
        activeIcon: Icons.inventory_2_rounded,
        label: 'Inventory',
        onTap: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ItemsScreen()),
        ),
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
