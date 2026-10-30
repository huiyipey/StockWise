import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/firestore_service.dart';
import '../services/store_session.dart';
import '../widgets/glass_bottom_nav.dart';
import '../widgets/inventory_ui.dart';
import '../widgets/inventory_expiry_range.dart';
import '../widgets/store_chat_button.dart';
import 'add_item_screen.dart';
import 'admin_item_detail_screen.dart';
import 'items_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'waste_analysis_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.inventoryStream, this.categoryStream});
  final Stream<List<InventoryBatch>>? inventoryStream;
  final Stream<List<StoreCategory>>? categoryStream;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String category = 'all';
  DateTimeRange? expiryRange;
  bool expiryAscending = true;
  late final inventory =
      widget.inventoryStream ?? FirestoreService.instance.watchInventory();
  late final categories =
      widget.categoryStream ?? FirestoreService.instance.watchCategoryRecords();

  @override
  Widget build(BuildContext context) => InventoryTheme(
    child: Builder(
      builder: (context) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              InventoryHeader(
                title: 'Overview',
                storeName: StoreSession.instance.store?.name ?? 'StockWise',
                trailing: StoreSession.instance.canManageMembers
                    ? const StoreChatButton()
                    : null,
              ),
              Expanded(
                child: StreamBuilder<List<StoreCategory>>(
                  stream: categories,
                  builder: (context, records) =>
                      StreamBuilder<List<InventoryBatch>>(
                        stream: inventory,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const InventoryEmpty(
                              title: 'Could not load inventory',
                              body:
                                  'Check your connection and reopen this page.',
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
                          final expiring =
                              active.where((item) {
                                final days = item.daysUntilExpiryFrom(now);
                                return days >= 0 &&
                                    days <= 7 &&
                                    (category == 'all' ||
                                        item.categoryId == category) &&
                                    _inRange(item.expiryAt);
                              }).toList()..sort(
                                (a, b) => expiryAscending
                                    ? a.expiryAt.compareTo(b.expiryAt)
                                    : b.expiryAt.compareTo(a.expiryAt),
                              );
                          return ListView(
                            padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                            children: [
                              _stats(active.length, expiring.length),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Expiring stock',
                                      style: TextStyle(
                                        fontSize: 20,
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
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              InventoryFilters(
                                compact: true,
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
                              const SizedBox(height: 18),
                              if (expiring.isEmpty)
                                const Card(
                                  child: InventoryEmpty(
                                    title: 'All clear for the next 7 days',
                                    body:
                                        'No stock expires in the next 7 days.',
                                    icon: Icons.check_rounded,
                                  ),
                                )
                              else
                                for (final item in expiring.take(5))
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: InventoryBatchTile(
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                child: InventoryButton(
                  label: 'Add inventory',
                  centered: false,
                  icon: Icons.add,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddItemScreen()),
                  ),
                ),
              ),
              _bottomNav(context),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _stats(int active, int expiring) => LayoutBuilder(
    builder: (context, constraints) {
      final activeCard = Container(
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
                fontSize: 10,
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
              style: const TextStyle(color: Color(0xFFC9DBCA), fontSize: 11),
            ),
          ],
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
              'Expiring in\n7 days',
              style: TextStyle(fontSize: 10.5, color: InventoryColors.muted),
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
        label: 'Items',
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
