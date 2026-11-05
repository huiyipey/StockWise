import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_models.dart';
import '../models/shelf_life.dart';
import '../services/firestore_service.dart';
import '../widgets/inventory_ui.dart';
import '../widgets/order_ui.dart';
import '../widgets/customer_ui.dart';
import '../widgets/catalogue_cache_notice.dart';
import 'product_image_screen.dart';
import 'cart_screen.dart';

class ItemDetailScreen extends StatefulWidget {
  const ItemDetailScreen({
    super.key,
    required this.item,
    this.addToCart,
    this.imageProvider,
    this.onOpenCart,
  });
  final InventoryBatch item;
  final Future<void> Function(InventoryBatch, int)? addToCart;
  final ImageProvider? imageProvider;
  final VoidCallback? onOpenCart;
  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  int quantity = 1;
  bool adding = false;
  InventoryBatch get item => widget.item;
  bool get selling => item.canSellAt(DateTime.now());
  String get unit =>
      const {
        'packs': 'pack',
        'bottles': 'bottle',
        'boxes': 'box',
        'loaves': 'loaf',
        'units': 'unit',
      }[item.unitLabel.toLowerCase()] ??
      item.unitLabel;

  @override
  Widget build(BuildContext context) => InventoryTheme(
    child: Builder(
      builder: (context) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              InventoryHeader(
                title: 'Product Details',
                back: true,
                onBack: () => Navigator.maybePop(context),
              ),
              const CatalogueCacheNotice(),
              Expanded(
                child: ListView(
                  key: const ValueKey('customer-product-scroll'),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    OrderPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ProductPhoto(
                            item: item,
                            provider: widget.imageProvider,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            '${inventoryCategoryName(item.categoryId, const [])} / Per $unit',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: InventoryColors.green,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            item.productName,
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ProductPricingCard(
                      key: const ValueKey('customer-product-pricing'),
                      item: item,
                    ),
                    const SizedBox(height: 16),
                    stockCard(),
                    const SizedBox(height: 16),
                    Container(
                      key: const ValueKey('customer-product-quantity'),
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: InventoryColors.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quantity',
                            style: TextStyle(
                              fontSize: 11,
                              color: InventoryColors.muted,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'Decrease quantity',
                                color: InventoryColors.green,
                                onPressed: adding || !selling || quantity <= 1
                                    ? null
                                    : () => setState(() => quantity--),
                                icon: const Icon(
                                  Icons.remove_circle_outline_rounded,
                                  size: 23,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  selling ? '$quantity' : '0',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Increase quantity',
                                color: InventoryColors.green,
                                onPressed:
                                    adding ||
                                        !selling ||
                                        quantity >= item.availableQuantity
                                    ? null
                                    : () => setState(() => quantity++),
                                icon: const Icon(
                                  Icons.add_circle_outline_rounded,
                                  size: 23,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!selling) ...[
                      const SizedBox(height: 16),
                      const OrderNotice(
                        'This product is no longer available for sale.',
                        error: true,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: InventoryColors.line)),
            ),
            child: InventoryButton(
              key: const ValueKey('customer-product-add'),
              label: adding ? 'Adding...' : 'Add to Cart',
              busy: adding,
              onPressed: selling ? add : null,
            ),
          ),
        ),
      ),
    ),
  );

  Color get expiryColour => switch (item.expiryColour) {
    ShelfLifeColour.green => InventoryColors.green,
    ShelfLifeColour.orange => InventoryColors.amber,
    ShelfLifeColour.red => InventoryColors.error,
  };
  Widget stockCard() {
    final days = item.daysUntilExpiry;
    final countdown = days < 0
        ? 'Expired'
        : days == 0
        ? 'Today'
        : '$days ${days == 1 ? 'day' : 'days'} left';
    return OrderPanel(
      key: const ValueKey('customer-product-stock'),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.shopping_bag_outlined,
                size: 28,
                color: InventoryColors.green,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Available',
                      style: TextStyle(
                        fontSize: 12,
                        color: InventoryColors.muted,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      '${item.availableQuantity} ${item.availableQuantity == 1 ? unit : item.unitLabel}',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 34),
          Row(
            children: [
              Icon(Icons.access_time_rounded, size: 28, color: expiryColour),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Expiry date',
                      style: TextStyle(
                        fontSize: 12,
                        color: InventoryColors.muted,
                      ),
                    ),
                    const SizedBox(height: 9),
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          Text(
                            DateFormat('d MMM yyyy').format(item.expiryAt),
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Container(
                            key: const ValueKey('customer-product-countdown'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: expiryColour.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              countdown,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: expiryColour,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> add() async {
    if (adding || !selling) return;
    setState(() {
      adding = true;
    });
    try {
      await (widget.addToCart ??
          (item, amount) => FirestoreService.instance.addToCart(
            item,
            quantity: amount,
          ))(item, quantity);
      if (mounted) {
        showAddedToCartFeedback(
          context,
          item.productName,
          onViewCart:
              widget.onOpenCart ??
              () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const CartScreen())),
        );
      }
    } catch (failure) {
      if (mounted) {
        setState(() => adding = false);
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Could Not Add to Cart'),
            content: Text(
              failure is StateError
                  ? failure.message
                  : 'Could not add this product. Please try again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => adding = false);
    }
  }
}

class _ProductPhoto extends StatefulWidget {
  const _ProductPhoto({required this.item, this.provider});
  final InventoryBatch item;
  final ImageProvider? provider;
  @override
  State<_ProductPhoto> createState() => _ProductPhotoState();
}

class _ProductPhotoState extends State<_ProductPhoto> {
  late final Future<ImageProvider?> image = resolve();
  Future<ImageProvider?> resolve() async {
    if (widget.provider != null) return widget.provider;
    final path = widget.item.imagePath;
    if (path == null || path.isEmpty) return null;
    final url = path.startsWith('http')
        ? path
        : await FirestoreService.instance.imageUrl(path);
    return url == null ? null : NetworkImage(url);
  }

  Widget placeholder() => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.image_outlined, size: 42, color: InventoryColors.muted),
        SizedBox(height: 12),
        Text(
          'No photo added',
          style: TextStyle(fontSize: 11, color: InventoryColors.muted),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: Container(
      height: 204,
      width: double.infinity,
      color: InventoryColors.background,
      child: FutureBuilder<ImageProvider?>(
        future: image,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          if (!snapshot.hasData || snapshot.hasError) return placeholder();
          return Tooltip(
            message: 'Enlarge image',
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => ProductImageScreen(
                    image: snapshot.data!,
                    title: widget.item.productName,
                    inventoryStyle: true,
                  ),
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image(
                    image: snapshot.data!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => placeholder(),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        Icons.fullscreen_rounded,
                        size: 20,
                        color: InventoryColors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}
