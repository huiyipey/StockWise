import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_models.dart';
import '../services/firestore_service.dart';
import '../services/inventory_list.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_bottom_nav.dart';
import '../widgets/expiry_date_filter.dart';
import '../widgets/stockwise_ui.dart';
import 'add_item_screen.dart';
import 'barcode_scanner_screen.dart';
import 'admin_item_detail_screen.dart';
import 'home_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'waste_analysis_screen.dart';
import 'category_management_screen.dart';
import '../widgets/category_name.dart';
import '../widgets/category_filter.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final searchController = TextEditingController();
  String query = '';
  String category = 'all';
  DateTimeRange? expiryRange;
  bool expiryAscending = true;

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
    if (value == null || !mounted) return;
    setState(() {
      searchController.text = value;
      query = value;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: Column(
        children: [
          const StockWiseHeader(title: 'Items'),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CategoryManagementScreen(),
                ),
              ),
              icon: const Icon(Icons.category_outlined),
              label: const Text('Manage categories'),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<InventoryBatch>>(
              stream: FirestoreService.instance.watchInventory(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _message(
                    'Could not load inventory',
                    '${snapshot.error}',
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final categories =
                    snapshot.data!
                        .map((item) => item.categoryId)
                        .toSet()
                        .toList()
                      ..sort();
                final today = DateTime.now();
                final items =
                    snapshot.data!.where((item) {
                      final matchesCategory =
                          category == 'all' || item.categoryId == category;
                      return matchesInventorySearch(item, query) &&
                          matchesCategory &&
                          _inRange(item.expiryAt);
                    }).toList()..sort(
                      (a, b) => compareAdminInventory(
                        a,
                        b,
                        ascending: expiryAscending,
                        today: today,
                      ),
                    );
                return ListView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 88),
                  children: [
                    AppSearchField(
                      hint: 'Search name or barcode',
                      controller: searchController,
                      suffixIcon: IconButton(
                        tooltip: 'Scan barcode to search',
                        onPressed: _scanBarcode,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                      ),
                      onChanged: (value) => setState(() => query = value),
                    ),
                    const SizedBox(height: 10),
                    _filters(categories),
                    const SizedBox(height: 14),
                    if (items.isEmpty)
                      _message(
                        'No inventory found',
                        'Add a product batch to this store.',
                      ),
                    ...items.map(_itemCard),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: SafeArea(top: false, child: _bottomNav(context)),
    floatingActionButton: FloatingActionButton(
      tooltip: 'Add item',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddItemScreen()),
      ),
      child: const Icon(Icons.add_rounded),
    ),
  );

  Widget _itemCard(InventoryBatch item) {
    final days = item.daysUntilExpiry;
    final color = days <= 2
        ? AppColors.danger
        : days <= 7
        ? AppColors.warning
        : AppColors.primaryDark;
    final label = days < 0
        ? 'Expired'
        : days == 0
        ? 'Today'
        : '$days days';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminItemDetailScreen(item: item),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                ProductArtwork(size: 58, imagePath: item.imagePath),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Exp: ${DateFormat('dd/MM/yyyy').format(item.expiryAt)}  •  Qty: ${item.quantityOnHand}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      CategoryName(
                        item.categoryId,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusPill(label, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filters(List<String> categories) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          CategoryFilter(
            categoryIds: categories,
            selected: category,
            onChanged: (value) => setState(() => category = value),
          ),
          const SizedBox(height: 10),
          ExpiryDateFilter(
            range: expiryRange,
            ascending: expiryAscending,
            onPickRange: _pickExpiryRange,
            onClearRange: () => setState(() => expiryRange = null),
            onToggleSort: () =>
                setState(() => expiryAscending = !expiryAscending),
          ),
        ],
      ),
    ),
  );

  bool _inRange(DateTime date) {
    final range = expiryRange;
    if (range == null) return true;
    final day = DateTime(date.year, date.month, date.day);
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(range.end.year, range.end.month, range.end.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  Future<void> _pickExpiryRange() async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
      initialDateRange: expiryRange,
    );
    if (selected != null) setState(() => expiryRange = selected);
  }

  Widget _message(String title, String body) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(
      children: [
        const Icon(
          Icons.inventory_2_outlined,
          size: 48,
          color: AppColors.muted,
        ),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text(body, textAlign: TextAlign.center),
      ],
    ),
  );

  Widget _bottomNav(BuildContext context) => GlassBottomNav(
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
