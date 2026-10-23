import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_models.dart';
import '../services/firestore_service.dart';
import '../services/cart_availability.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_bottom_nav.dart';
import '../widgets/stockwise_ui.dart';
import 'checkout_screen.dart';
import 'item_detail_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'shop_screen.dart';

class CartScreen extends StatefulWidget {
  final Stream<List<CartLine>>? cartStream;
  final Stream<List<InventoryBatch>>? inventoryStream;
  final Future<void> Function(String)? removeItem;

  const CartScreen({
    super.key,
    this.cartStream,
    this.inventoryStream,
    this.removeItem,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late final cart = widget.cartStream ?? FirestoreService.instance.watchCart();
  late final inventory =
      widget.inventoryStream ?? FirestoreService.instance.watchInventory();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const StockWiseHeader(title: 'Cart'),
          Expanded(
            child: StreamBuilder<List<CartLine>>(
              stream: cart,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Could not load cart: ${snapshot.error}'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final lines = snapshot.data!;
                final subtotal = lines.fold<int>(
                  0,
                  (sum, line) => sum + line.lineTotalCents,
                );
                if (lines.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 60,
                          color: AppColors.muted,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Your cart is empty',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  );
                }
                return StreamBuilder<List<InventoryBatch>>(
                  stream: inventory,
                  builder: (context, stockSnapshot) {
                    if (stockSnapshot.hasError) {
                      return const Center(
                        child: Text(
                          'Could not check item availability. Please reopen your cart.',
                        ),
                      );
                    }
                    if (!stockSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final batches = {
                      for (final item in stockSnapshot.data!) item.id: item,
                    };
                    final now = DateTime.now();
                    final unavailable = <String, String>{};
                    for (final line in lines) {
                      final reason = cartUnavailableReason(
                        line,
                        batches[line.batchId],
                        now,
                      );
                      if (reason != null) unavailable[line.id] = reason;
                    }
                    return ListView(
                      padding: const EdgeInsets.all(18),
                      children: [
                        if (unavailable.isNotEmpty)
                          _unavailableNotice(
                            lines
                                .where(
                                  (line) => unavailable.containsKey(line.id),
                                )
                                .toList(),
                          ),
                        ...lines.map(
                          (line) => _line(
                            context,
                            line,
                            batches[line.batchId],
                            unavailable[line.id],
                          ),
                        ),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                const Text(
                                  'Subtotal',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                const Spacer(),
                                Text(
                                  'RM ${(subtotal / 100).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: unavailable.isNotEmpty
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CheckoutScreen(lines: lines),
                                  ),
                                ),
                          child: const Text('CHECKOUT'),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _bottomNav(context),
        ],
      ),
    ),
  );

  Widget _unavailableNotice(List<CartLine> lines) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Card(
      color: AppColors.danger.withValues(alpha: .08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.danger),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'some item(s) are no longer available. Please remove from your cart.',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: 8),
            ...lines.map((line) => Text('• ${line.productName}')),
          ],
        ),
      ),
    ),
  );

  Widget _line(
    BuildContext context,
    CartLine line,
    InventoryBatch? item,
    String? unavailable,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: item == null
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item)),
              ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ProductArtwork(size: 62, imagePath: line.imagePath),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.productName,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      'Exp: ${DateFormat('dd/MM/yyyy').format(line.expiryAt)}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 7),
                    if (unavailable != null)
                      Text(
                        unavailable,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: item?.canSellAt(DateTime.now()) != true
                              ? null
                              : () =>
                                    _quantity(context, line, line.quantity - 1),
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                        ),
                        Text(
                          '${line.quantity}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        IconButton(
                          onPressed: unavailable != null
                              ? null
                              : () =>
                                    _quantity(context, line, line.quantity + 1),
                          icon: const Icon(Icons.add_circle_outline_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'RM ${(line.lineTotalCents / 100).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  IconButton(
                    color: AppColors.danger,
                    tooltip: 'Remove',
                    onPressed: () => _remove(context, line),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _remove(BuildContext context, CartLine line) async {
    try {
      await (widget.removeItem ?? FirestoreService.instance.removeCartItem)(
        line.id,
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _quantity(
    BuildContext context,
    CartLine line,
    int quantity,
  ) async {
    try {
      await FirestoreService.instance.updateCartQuantity(line, quantity);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Widget _bottomNav(BuildContext context) => GlassBottomNav(
    currentIndex: 1,
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
      const NavItem(
        icon: Icons.shopping_cart_outlined,
        activeIcon: Icons.shopping_cart_rounded,
        label: 'Cart',
      ),
      NavItem(
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long_rounded,
        label: 'Orders',
        onTap: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OrdersScreen(isAdmin: false)),
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
