import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_models.dart';
import '../services/firestore_service.dart';
import '../services/store_session.dart';
import '../widgets/glass_bottom_nav.dart';
import '../widgets/inventory_ui.dart';
import '../widgets/order_ui.dart';
import 'cart_screen.dart';
import 'home_screen.dart';
import 'items_screen.dart';
import 'order_detail_screen.dart';
import 'profile_screen.dart';
import 'shop_screen.dart';
import 'waste_analysis_screen.dart';

class OrdersScreen extends StatefulWidget {
  final bool isAdmin;
  final String initialStatus;
  final Stream<List<StoreOrder>> Function()? orderSource;

  const OrdersScreen({
    super.key,
    this.isAdmin = true,
    this.initialStatus = 'all',
    this.orderSource,
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late String status = widget.initialStatus;
  String query = '';
  final search = TextEditingController();
  late Stream<List<StoreOrder>> orders = watch();

  Stream<List<StoreOrder>> watch() =>
      widget.orderSource?.call() ??
      FirestoreService.instance.watchOrders(admin: widget.isAdmin);

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
          bottom: false,
          child: Column(
            children: [
              InventoryHeader(
                title: widget.isAdmin ? 'Orders' : 'Order history',
                storeName: StoreSession.instance.store?.name ?? 'StockWise',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: TextField(
                        key: const ValueKey('order-search'),
                        controller: search,
                        textAlignVertical: TextAlignVertical.center,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          floatingLabelBehavior: FloatingLabelBehavior.never,
                          constraints: const BoxConstraints(minHeight: 46),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          hintText: 'Search order number and date',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 21,
                          ),
                          suffixIcon: query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 19,
                                  ),
                                  onPressed: () => setState(() {
                                    search.clear();
                                    query = '';
                                  }),
                                ),
                        ),
                        onChanged: (value) => setState(() => query = value),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OrderStatusFilter(
                      selected: status,
                      onSelected: (value) => setState(() => status = value),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<StoreOrder>>(
                  stream: orders,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          OrderEmpty(
                            'Could not load orders',
                            onRetry: () => setState(() => orders = watch()),
                          ),
                        ],
                      );
                    }
                    if (!snapshot.hasData) {
                      return ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          for (var i = 0; i < 3; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Container(
                                height: 140,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8ECE7),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: i == 1
                                    ? const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                        ],
                      );
                    }
                    final needle = query.trim().toLowerCase().replaceFirst(
                      RegExp(r'^#'),
                      '',
                    );
                    final filtered = snapshot.data!
                        .where(
                          (order) =>
                              (status == 'all' || order.status == status) &&
                              [
                                order.orderNumber,
                                DateFormat('d MMM yyyy').format(order.placedAt),
                                DateFormat('dd/MM/yyyy').format(order.placedAt),
                                DateFormat('yyyy-MM-dd').format(order.placedAt),
                                DateFormat(
                                  'd MMMM yyyy',
                                ).format(order.placedAt),
                              ].any(
                                (value) => value.toLowerCase().contains(needle),
                              ),
                        )
                        .toList();
                    return ListView(
                      key: const ValueKey('orders-list'),
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                      children: [
                        if (filtered.isEmpty)
                          OrderEmpty(
                            needle.isNotEmpty
                                ? 'No matching orders'
                                : snapshot.data!.isEmpty
                                ? 'No orders yet'
                                : status == 'all'
                                ? 'No orders yet'
                                : {
                                        'to_pay': 'No orders to pay',
                                        'to_ship': 'No orders to ship',
                                        'to_receive': 'No orders to receive',
                                        'completed': 'No completed orders',
                                        'cancelled': 'No cancelled orders',
                                      }[status] ??
                                      'No orders',
                          ),
                        for (final order in filtered)
                          OrderListCard(
                            order: order,
                            enlarged: true,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderDetailScreen(
                                  order: order,
                                  isAdmin: widget.isAdmin,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(top: false, child: _bottomNav(context)),
      ),
    ),
  );

  Widget _bottomNav(BuildContext context) {
    if (widget.isAdmin) {
      return InventoryBottomNav(
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
    return InventoryBottomNav(
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
