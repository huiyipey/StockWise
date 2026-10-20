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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
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
                final expiring = active
                    .where((item) => item.daysUntilExpiry <= 7)
                    .toList();
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
