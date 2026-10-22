import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_models.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_bottom_nav.dart';
import '../widgets/stockwise_ui.dart';
import 'add_item_screen.dart';
import 'admin_item_detail_screen.dart';
import 'home_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'waste_analysis_screen.dart';
import 'category_management_screen.dart';
import '../widgets/category_name.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  String query = '';
  String category = 'all';
  DateTimeRange? expiryRange;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          StockWiseHeader(
            title: 'Items',
            trailing: IconButton(
              tooltip: 'Add item',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddItemScreen()),
              ),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
            ),
          ),
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
                final items = snapshot.data!.where((item) {
                  final matchesName = item.productName.toLowerCase().contains(
                    query.toLowerCase(),
                  );
                  final matchesCategory =
                      category == 'all' || item.categoryId == category;
                  return matchesName &&
                      matchesCategory &&
                      _inRange(item.expiryAt);
                }).toList();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
                  children: [
                    AppSearchField(
                      hint: 'Search inventory',
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
    floatingActionButton: FloatingActionButton(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddItemScreen()),
      ),
      child: const Icon(Icons.add_rounded),
    ),
    bottomNavigationBar: SafeArea(top: false, child: _bottomNav(context)),
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
          DropdownButtonFormField<String>(
            initialValue: categories.contains(category) ? category : 'all',
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              const DropdownMenuItem(
                value: 'all',
                child: Text('All categories'),
              ),
              ...categories.map(
                (value) =>
                    DropdownMenuItem(value: value, child: CategoryName(value)),
              ),
            ],
            onChanged: (value) => setState(() => category = value ?? 'all'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickExpiryRange,
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(
                    expiryRange == null
                        ? 'Filter expiry date'
                        : '${DateFormat('dd/MM/yy').format(expiryRange!.start)} – ${DateFormat('dd/MM/yy').format(expiryRange!.end)}',
                  ),
                ),
              ),
              if (expiryRange != null)
                IconButton(
                  tooltip: 'Clear date filter',
                  onPressed: () => setState(() => expiryRange = null),
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
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
