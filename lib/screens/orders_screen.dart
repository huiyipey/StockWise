import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_models.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_bottom_nav.dart';
import '../widgets/stockwise_ui.dart';
import 'cart_screen.dart';
import 'home_screen.dart';
import 'items_screen.dart';
import 'order_detail_screen.dart';
import 'profile_screen.dart';
import 'shop_screen.dart';
import 'waste_analysis_screen.dart';

class OrdersScreen extends StatefulWidget {
  final bool isAdmin;

  const OrdersScreen({super.key, this.isAdmin = true});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String status = 'to_pay';
  String query = '';

  static const statuses = ['to_pay', 'to_ship', 'to_receive', 'completed'];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          StockWiseHeader(title: widget.isAdmin ? 'Orders' : 'Order History'),
          Expanded(
            child: StreamBuilder<List<StoreOrder>>(
              stream: FirestoreService.instance.watchOrders(
                admin: widget.isAdmin,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Could not load orders: ${snapshot.error}'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final orders = snapshot.data!
                    .where(
                      (order) =>
                          order.status == status &&
                          order.orderNumber.toLowerCase().contains(
                            query.toLowerCase(),
                          ),
                    )
                    .toList();
                return ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    AppSearchField(
                      hint: 'Search order number',
                      onChanged: (value) => setState(() => query = value),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: statuses
                            .map(
                              (value) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  selected: status == value,
                                  label: Text(_label(value)),
                                  onSelected: (_) =>
                                      setState(() => status = value),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (orders.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(child: Text('No orders in this status.')),
                      ),
                    ...orders.map((order) => _orderCard(order)),
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

  Widget _orderCard(StoreOrder order) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '#${order.orderNumber}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            StatusPill(
              _label(order.paymentStatus),
              color: order.paymentStatus == 'paid'
                  ? AppColors.primaryDark
                  : AppColors.warning,
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '${_label(order.fulfillmentType)}  •  ${DateFormat('dd MMM yyyy').format(order.placedAt)}\nRM ${(order.totalCents / 100).toStringAsFixed(2)}',
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                OrderDetailScreen(order: order, isAdmin: widget.isAdmin),
          ),
        ),
      ),
    ),
  );

  static String _label(String value) => value
      .split('_')
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  Widget _bottomNav(BuildContext context) {
    if (widget.isAdmin) {
      return GlassBottomNav(
        currentIndex: 3,
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
          const NavItem(
            icon: Icons.shopping_cart_outlined,
            activeIcon: Icons.shopping_cart_rounded,
            label: 'Orders',
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
    return GlassBottomNav(
      currentIndex: 2,
      items: [
        NavItem(
          icon: Icons.storefront_outlined,
          activeIcon: Icons.storefront_rounded,
          label: 'Shop',
          onTap: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ShopScreen()),
          ),
        ),
        NavItem(
          icon: Icons.shopping_cart_outlined,
          activeIcon: Icons.shopping_cart_rounded,
          label: 'Cart',
          onTap: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const CartScreen()),
          ),
        ),
        const NavItem(
          icon: Icons.receipt_long_outlined,
          activeIcon: Icons.receipt_long_rounded,
          label: 'Orders',
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
}
