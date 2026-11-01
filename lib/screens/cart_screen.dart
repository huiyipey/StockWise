import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_models.dart';
import '../services/firestore_service.dart';
import '../services/cart_availability.dart';
import '../services/store_session.dart';
import '../widgets/glass_bottom_nav.dart';
import '../widgets/inventory_ui.dart';
import '../widgets/order_ui.dart';
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
  final Future<void> Function(CartLine, int)? changeQuantity;

  const CartScreen({
    super.key,
    this.cartStream,
    this.inventoryStream,
    this.removeItem,
    this.changeQuantity,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final pending = <String>{};
  late final cart = widget.cartStream ?? FirestoreService.instance.watchCart();
  late final inventory =
      widget.inventoryStream ?? FirestoreService.instance.watchInventory();

  @override
  Widget build(BuildContext context) => InventoryTheme(
    child: Builder(
      builder: (context) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              InventoryHeader(
                title: 'Cart',
                storeName: StoreSession.instance.store?.name ?? 'StockWise',
              ),
              Expanded(
                child: StreamBuilder<List<CartLine>>(
                  stream: cart,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const SingleChildScrollView(
                        child: OrderEmpty(
                          'Could not load your cart',
                          icon: Icons.shopping_cart_outlined,
                        ),
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
                      return const SingleChildScrollView(
                        child: OrderEmpty(
                          'Your cart is empty',
                          icon: Icons.shopping_cart_outlined,
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
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
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
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          children: [
                            if (unavailable.isNotEmpty)
                              _unavailableNotice(
                                lines
                                    .where(
                                      (line) =>
                                          unavailable.containsKey(line.id),
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
                            OrderTotals(subtotal: subtotal),
                            const SizedBox(height: 16),
                            InventoryButton(
                              label: 'Checkout',
                              onPressed:
                                  unavailable.isNotEmpty || pending.isNotEmpty
                                  ? null
                                  : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            CheckoutScreen(lines: lines),
                                      ),
                                    ),
                            ),
                          ],
                        );
                      },
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

  Widget _unavailableNotice(List<CartLine> lines) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: const OrderNotice(
      'Some items are no longer available. Please remove them from your cart.',
      error: true,
    ),
  );

  Widget _line(
    BuildContext context,
    CartLine line,
    InventoryBatch? item,
    String? unavailable,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: item == null || unavailable != null || pending.contains(line.id)
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item)),
              ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProductArtwork(size: 62, imagePath: line.imagePath),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line.productName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Exp: ${DateFormat('d MMM yyyy').format(line.expiryAt)}',
                          style: const TextStyle(
                            color: InventoryColors.muted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 7),
                        if (unavailable != null)
                          Text(
                            unavailable,
                            style: const TextStyle(
                              fontSize: 12,
                              color: InventoryColors.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Decrease quantity',
                          color: InventoryColors.green,
                          onPressed:
                              pending.contains(line.id) ||
                                  item?.canSellAt(DateTime.now()) != true
                              ? null
                              : () =>
                                    _quantity(context, line, line.quantity - 1),
                          icon: const Icon(
                            Icons.remove_circle_outline_rounded,
                            size: 21,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            '${line.quantity}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Increase quantity',
                          color: InventoryColors.green,
                          onPressed:
                              pending.contains(line.id) ||
                                  unavailable != null ||
                                  line.quantity >=
                                      (item?.availableQuantity ?? 0)
                              ? null
                              : () =>
                                    _quantity(context, line, line.quantity + 1),
                          icon: const Icon(
                            Icons.add_circle_outline_rounded,
                            size: 21,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Text(
                      orderMoney(line.lineTotalCents),
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    color: InventoryColors.error,
                    tooltip: 'Remove',
                    onPressed: pending.contains(line.id)
                        ? null
                        : () => _remove(context, line),
                    icon: pending.contains(line.id)
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline_rounded, size: 21),
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
    if (pending.contains(line.id)) return;
    setState(() => pending.add(line.id));
    try {
      await (widget.removeItem ?? FirestoreService.instance.removeCartItem)(
        line.id,
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          inventoryFeedback(
            'Could not remove the item. Please try again.',
            error: true,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => pending.remove(line.id));
    }
  }

  Future<void> _quantity(
    BuildContext context,
    CartLine line,
    int quantity,
  ) async {
    if (pending.contains(line.id)) return;
    setState(() => pending.add(line.id));
    try {
      await (widget.changeQuantity ??
          FirestoreService.instance.updateCartQuantity)(line, quantity);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          inventoryFeedback(
            'Could not update the quantity. Please try again.',
            error: true,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => pending.remove(line.id));
    }
  }

  Widget _bottomNav(BuildContext context) => InventoryBottomNav(
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
