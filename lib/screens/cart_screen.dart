import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_models.dart';
import '../services/firestore_service.dart';
import '../services/cart_availability.dart';
import '../services/store_session.dart';
import '../widgets/glass_bottom_nav.dart';
import '../widgets/inventory_ui.dart';
import '../widgets/order_ui.dart';
import '../widgets/commerce_quote.dart';
import '../widgets/customer_ui.dart';
import '../widgets/catalogue_cache_notice.dart';
import '../widgets/stockwise_ui.dart';
import 'checkout_screen.dart';
import 'item_detail_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'shop_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({
    super.key,
    this.cartStream,
    this.inventoryStream,
    this.removeItem,
    this.changeQuantity,
    this.quoteLoader,
  });
  final Stream<List<CartLine>>? cartStream;
  final Stream<List<InventoryBatch>>? inventoryStream;
  final Future<void> Function(String)? removeItem;
  final Future<void> Function(CartLine, int)? changeQuantity;
  final Future<Map<String, dynamic>> Function()? quoteLoader;
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final pending = <String>{};
  late final cart = (widget.cartStream ?? FirestoreService.instance.watchCart())
      .asBroadcastStream(onCancel: (subscription) => subscription.cancel());
  late final inventory =
      widget.inventoryStream ?? FirestoreService.instance.watchInventory();
  String? quoteKey;
  Future<Map<String, dynamic>>? quote;
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
              const CatalogueCacheNotice(),
              Expanded(
                child: StreamBuilder<List<CartLine>>(
                  stream: cart,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
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
                    if (lines.isEmpty) {
                      return const Center(
                        child: SingleChildScrollView(
                          child: OrderEmpty(
                            'Your cart is empty',
                            icon: Icons.shopping_cart_outlined,
                          ),
                        ),
                      );
                    }
                    return StreamBuilder<List<InventoryBatch>>(
                      stream: inventory,
                      builder: (context, stock) {
                        if (stock.hasError) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Could not check item availability. Please reopen your cart.',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          );
                        }
                        if (!stock.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final batches = {
                          for (final item in stock.data!) item.id: item,
                        };
                        final unavailable = <String, String>{};
                        for (final line in lines) {
                          final reason = cartUnavailableReason(
                            line,
                            batches[line.batchId],
                            DateTime.now(),
                          );
                          if (reason != null) unavailable[line.id] = reason;
                        }
                        if (unavailable.isNotEmpty ||
                            (widget.cartStream != null &&
                                widget.quoteLoader == null)) {
                          return _list(context, lines, batches, unavailable);
                        }
                        final revision =
                            '${lines.map((l) => '${l.id}:${l.quantity}').join(',')}/${batches.values.map((b) => '${b.id}:${b.quantityOnHand}:${b.sellingPriceCents}:${b.promotion}').join(',')}';
                        if (quoteKey != revision) {
                          quoteKey = revision;
                          quote =
                              (widget.quoteLoader ??
                              () => FirestoreService.instance.quoteCart(''))();
                        }
                        return FutureBuilder<Map<String, dynamic>>(
                          future: quote,
                          builder: (context, result) => _list(
                            context,
                            lines,
                            batches,
                            unavailable,
                            pricing: result.data,
                            loading: !result.hasData && !result.hasError,
                            failed: result.hasError,
                          ),
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

  Widget _list(
    BuildContext context,
    List<CartLine> lines,
    Map<String, InventoryBatch> batches,
    Map<String, String> unavailable, {
    Map<String, dynamic>? pricing,
    bool loading = false,
    bool failed = false,
  }) {
    int lineTotal(CartLine line) {
      if (pricing != null) {
        return (pricing['lines'] as List)
            .where(
              (raw) =>
                  raw['batchId'] == line.batchId &&
                  (raw['kind'] == 'purchase' ||
                      raw['sourceBatchId'] == line.batchId),
            )
            .fold<int>(
              0,
              (sum, raw) => sum + (raw['lineTotalCents'] as num).toInt(),
            );
      }
      return (batches[line.batchId]?.sellingPriceCents ?? line.unitPriceCents) *
          line.quantity;
    }

    final subtotal =
        (pricing?['subtotalCents'] as num?)?.toInt() ??
        lines.fold<int>(0, (sum, line) => sum + lineTotal(line));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        if (unavailable.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Some items are no longer available. Please remove them from your cart.',
              style: TextStyle(
                fontSize: 14,
                color: InventoryColors.error,
                height: 1.5,
              ),
            ),
          ),
        for (final line in lines)
          _line(
            context,
            line,
            batches[line.batchId],
            unavailable[line.id],
            lineTotal(line),
          ),
        if (pricing != null) QuoteLines(quote: pricing),
        if (loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (failed)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Could not calculate live pricing. Reopen your cart to retry.',
              style: TextStyle(fontSize: 14, color: InventoryColors.error),
            ),
          ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const label = Text(
                'Subtotal',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              );
              final value = Text(
                orderMoney(subtotal),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              );
              if (constraints.maxWidth < 280 &&
                  MediaQuery.textScalerOf(context).scale(18) > 22) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    label,
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: value,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  const Expanded(child: label),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: value,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        InventoryButton(
          label: 'Checkout',
          onPressed:
              unavailable.isNotEmpty || pending.isNotEmpty || loading || failed
              ? null
              : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CheckoutScreen(lines: lines),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _line(
    BuildContext context,
    CartLine line,
    InventoryBatch? item,
    String? unavailable,
    int total,
  ) {
    final blocked = unavailable != null;
    final price = item?.sellingPriceCents ?? line.unitPriceCents;
    final unit = item?.unitLabel ?? 'unit';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: blocked ? InventoryColors.error : Colors.transparent,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: item == null || blocked || pending.contains(line.id)
              ? null
              : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ItemDetailScreen(item: item),
                  ),
                ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProductArtwork(
                      size: 72,
                      imagePath: item?.imagePath ?? line.imagePath,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.productName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${orderMoney(price)} / $unit${blocked ? ' / Qty ${line.quantity}' : ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: InventoryColors.muted,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Exp: ${DateFormat('dd MMM yyyy').format(line.expiryAt)}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: InventoryColors.amber,
                            ),
                          ),
                          if (blocked)
                            Padding(
                              padding: const EdgeInsets.only(top: 7),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAE7E0),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  unavailable,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: InventoryColors.error,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (item?.bundlePromotion == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 9, left: 84),
                    child: PromotionDescription(
                      item!.promotionLabel,
                      fontSize: 11,
                    ),
                  ),
                const SizedBox(height: 10),
                _controls(context, line, item, blocked, total),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _controls(
    BuildContext context,
    CartLine line,
    InventoryBatch? item,
    bool blocked,
    int total,
  ) {
    final remove = SizedBox(
      width:
          70 * (MediaQuery.textScalerOf(context).scale(11) / 11).clamp(1, 1.8),
      child: Tooltip(
        message: 'Remove',
        child: TextButton(
          onPressed: pending.contains(line.id)
              ? null
              : () => _remove(context, line),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: InventoryColors.error,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              pending.contains(line.id)
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline_rounded, size: 18),
              const SizedBox(width: 3),
              const Flexible(
                child: Text(
                  'Remove',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final quantity = SizedBox(
      width: 112,
      child: Container(
        decoration: BoxDecoration(
          color: InventoryColors.soft.withValues(alpha: .4),
          border: Border.all(color: InventoryColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Decrease quantity',
              constraints: const BoxConstraints.tightFor(width: 32, height: 36),
              padding: EdgeInsets.zero,
              onPressed: pending.contains(line.id) || line.quantity <= 1
                  ? null
                  : () => _quantity(context, line, line.quantity - 1),
              icon: const Icon(Icons.remove_rounded, size: 18),
            ),
            Expanded(
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
              constraints: const BoxConstraints.tightFor(width: 32, height: 36),
              padding: EdgeInsets.zero,
              onPressed:
                  pending.contains(line.id) ||
                      line.quantity >= (item?.availableQuantity ?? 0)
                  ? null
                  : () => _quantity(context, line, line.quantity + 1),
              icon: const Icon(Icons.add_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
    final price = Text(
      orderMoney(total),
      textAlign: TextAlign.right,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 280 ||
            MediaQuery.textScalerOf(context).scale(14) > 18) {
          return Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [remove, if (!blocked) quantity, price],
          );
        }
        return Row(
          children: [
            remove,
            const SizedBox(width: 12),
            if (!blocked)
              Expanded(
                child: Align(alignment: Alignment.centerLeft, child: quantity),
              )
            else
              const Spacer(),
            const SizedBox(width: 8),
            price,
          ],
        );
      },
    );
  }

  Future<void> _remove(BuildContext context, CartLine line) async {
    if (pending.contains(line.id)) return;
    if (!await showOrderConfirmation(
          context: context,
          title: 'Remove from Cart?',
          message: 'Remove ${line.productName} from your cart?',
          action: 'Remove',
          cancel: 'Keep Item',
          danger: true,
        ) ||
        !context.mounted) {
      return;
    }
    setState(() => pending.add(line.id));
    try {
      await (widget.removeItem ?? FirestoreService.instance.removeCartItem)(
        line.id,
      );
      if (context.mounted) {
        showCustomerFeedback(context, 'Item removed from cart');
      }
    } catch (_) {
      if (context.mounted) {
        showCustomerFeedback(
          context,
          'Could not remove the item. Please try again.',
          error: true,
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
    } catch (_) {
      if (context.mounted) {
        showCustomerFeedback(
          context,
          'Could not update the quantity. Please try again.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => pending.remove(line.id));
    }
  }

  Widget _bottomNav(BuildContext context) => CustomerBottomNav(
    cartCountStream: cart.map(
      (lines) => lines.fold<int>(0, (sum, line) => sum + line.quantity),
    ),
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
