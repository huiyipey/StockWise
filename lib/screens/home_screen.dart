import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_models.dart';
import '../services/firestore_service.dart';
import '../services/store_session.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_bottom_nav.dart';
import '../widgets/stockwise_ui.dart';
import 'add_item_screen.dart';
import 'admin_item_detail_screen.dart';
import 'items_screen.dart';
import 'notifications_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'waste_analysis_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
<<<<<<< HEAD
=======
<<<<<<< HEAD
>>>>>>> c329d3aa1357b4e87b680ad91ce3b6d980a28249
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String category = 'all';
  DateTimeRange? expiryRange;

  @override
<<<<<<< HEAD
=======
=======
>>>>>>> 831768e476072760b30a26d67dfa6f0d1864723f
>>>>>>> c329d3aa1357b4e87b680ad91ce3b6d980a28249
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          StockWiseHeader(
            title: StoreSession.instance.store?.name ?? 'StockWise',
            trailing: IconButton(
              tooltip: 'Notifications',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
              icon: const Icon(
                Icons.notifications_outlined,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<InventoryBatch>>(
              stream: FirestoreService.instance.watchInventory(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Could not load inventory: ${snapshot.error}'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final active = snapshot.data!
                    .where(
                      (item) =>
                          item.status == 'active' && item.quantityOnHand > 0,
                    )
                    .toList();
<<<<<<< HEAD
=======
<<<<<<< HEAD
>>>>>>> c329d3aa1357b4e87b680ad91ce3b6d980a28249
                final categories =
                    active.map((item) => item.categoryId).toSet().toList()
                      ..sort();
                final expiring = active.where((item) {
                  if (item.daysUntilExpiry > 7) return false;
                  if (category != 'all' && item.categoryId != category) {
                    return false;
                  }
                  return _inRange(item.expiryAt);
                }).toList();
<<<<<<< HEAD
=======
=======
                final expiring = active
                    .where((item) => item.daysUntilExpiry <= 7)
                    .toList();
>>>>>>> 831768e476072760b30a26d67dfa6f0d1864723f
>>>>>>> c329d3aa1357b4e87b680ad91ce3b6d980a28249
                return ListView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                  children: [
                    Text(
                      'Inventory overview',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _stat(
                            'Active batches',
                            '${active.length}',
                            AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _stat(
                            'Expiring in 7 days',
                            '${expiring.length}',
                            AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Expiring stock',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
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
                          child: const Text('View all'),
                        ),
                      ],
                    ),
<<<<<<< HEAD
                    _filters(categories),
                    const SizedBox(height: 10),
=======
<<<<<<< HEAD
                    _filters(categories),
                    const SizedBox(height: 10),
=======
>>>>>>> 831768e476072760b30a26d67dfa6f0d1864723f
>>>>>>> c329d3aa1357b4e87b680ad91ce3b6d980a28249
                    if (expiring.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('No stock expires in the next 7 days.'),
                        ),
                      ),
                    ...expiring
                        .take(5)
                        .map((item) => _batchCard(context, item)),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddItemScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('ADD INVENTORY'),
                    ),
                  ],
                );
              },
            ),
          ),
          _bottomNav(context),
        ],
      ),
    ),
  );

  Widget _stat(String label, String value, Color color) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
<<<<<<< HEAD
=======
<<<<<<< HEAD
>>>>>>> c329d3aa1357b4e87b680ad91ce3b6d980a28249

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
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(value.replaceAll('-', ' ')),
                ),
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
=======
>>>>>>> 831768e476072760b30a26d67dfa6f0d1864723f

  Widget _batchCard(BuildContext context, InventoryBatch item) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.all(12),
      leading: ProductArtwork(size: 52, imagePath: item.imagePath),
      title: Text(
        item.productName,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        'Exp: ${DateFormat('dd/MM/yyyy').format(item.expiryAt)}  •  Qty: ${item.quantityOnHand}',
      ),
      trailing: StatusPill(
        item.daysUntilExpiry < 0 ? 'Expired' : '${item.daysUntilExpiry} days',
        color: item.daysUntilExpiry <= 2 ? AppColors.danger : AppColors.warning,
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AdminItemDetailScreen(item: item)),
      ),
    ),
  );

  Widget _bottomNav(BuildContext context) => GlassBottomNav(
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
