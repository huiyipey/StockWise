import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/firestore_service.dart';
import '../services/store_session.dart';
import '../widgets/glass_bottom_nav.dart' show NavItem;
import '../widgets/inventory_expiry_range.dart';
import '../widgets/inventory_ui.dart';
import '../widgets/shop_ui.dart';
import '../widgets/store_chat_button.dart';
import 'cart_screen.dart';
import 'item_detail_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'shopping_assistant_screen.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({
    super.key,
    this.inventoryStream,
    this.categoriesStream,
    this.cartCountStream,
    this.chatButton,
    this.onAddToCart,
    this.onOpenCart,
    this.onOpenProduct,
    this.onOpenAssistant,
    this.onRetry,
    this.imageProvider,
    this.now,
  });
  final Stream<List<InventoryBatch>>? inventoryStream;
  final Stream<List<StoreCategory>>? categoriesStream;
  final Stream<int>? cartCountStream;
  final Widget? chatButton;
  final Future<void> Function(InventoryBatch)? onAddToCart;
  final VoidCallback? onOpenCart, onOpenAssistant, onRetry;
  final ValueChanged<InventoryBatch>? onOpenProduct;
  final ImageProvider? Function(InventoryBatch)? imageProvider;
  final DateTime Function()? now;
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final search = TextEditingController();
  final adding = <String>{};
  late var inventory =
      widget.inventoryStream ?? FirestoreService.instance.watchInventory();
  late final categories =
      widget.categoriesStream ??
      FirestoreService.instance.watchCategoryRecords();
  late final cartCount =
      widget.cartCountStream ??
      FirestoreService.instance.watchCart().map((lines) => lines.length);
  String category = 'all';
  DateTimeRange? expiryRange;
  bool ascending = true;
  DateTime get now => widget.now?.call() ?? DateTime.now();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void openCart() {
    if (widget.onOpenCart != null) {
      widget.onOpenCart!();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartScreen()),
    );
  }

  void openProduct(InventoryBatch item) {
    if (widget.onOpenProduct != null) {
      widget.onOpenProduct!(item);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item)),
    );
  }

  void openAssistant() {
    if (widget.onOpenAssistant != null) {
      widget.onOpenAssistant!();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ShoppingAssistantScreen()),
    );
  }

  @override
  Widget build(BuildContext context) => InventoryTheme(
    child: Builder(
      builder: (context) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: StreamBuilder<List<StoreCategory>>(
            stream: categories,
            builder: (context, categorySnapshot) =>
                StreamBuilder<List<InventoryBatch>>(
                  stream: inventory,
                  builder: (context, snapshot) => _content(
                    context,
                    snapshot,
                    categorySnapshot.data ?? const [],
                  ),
                ),
          ),
        ),
        bottomNavigationBar: SafeArea(top: false, child: _bottomNav()),
      ),
    ),
  );

  Widget _content(
    BuildContext context,
    AsyncSnapshot<List<InventoryBatch>> snapshot,
    List<StoreCategory> records,
  ) {
    final sellable = (snapshot.data ?? const <InventoryBatch>[])
        .where((item) => item.canSellAt(now))
        .toList();
    final ids = sellable.map((item) => item.categoryId).toSet().toList()
      ..sort();
    final effectiveCategory = ids.contains(category) ? category : 'all';
    final hasFilters =
        search.text.trim().isNotEmpty ||
        effectiveCategory != 'all' ||
        expiryRange != null;
    final filtered =
        sellable.where((item) => _matches(item, effectiveCategory)).toList()
          ..sort((a, b) {
            final result = ascending
                ? a.expiryAt.compareTo(b.expiryAt)
                : b.expiryAt.compareTo(a.expiryAt);
            return result == 0
                ? a.productName.compareTo(b.productName)
                : result;
          });
    final promotions = filtered
        .where(
          (item) => item.promotionEnabled && item.promotionPriceCents != null,
        )
        .toList();
    final regular = filtered
        .where((item) => !promotions.contains(item))
        .toList();
    return CustomScrollView(
      key: const ValueKey('shop-scroll'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.storefront_outlined,
                                size: 15,
                                color: InventoryColors.green,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  StoreSession.instance.store?.name ??
                                      'Your store',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: InventoryColors.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Shop',
                            style: TextStyle(
                              fontSize: 29,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    widget.chatButton ??
                        const StoreChatButton(inventoryStyle: true),
                    const SizedBox(width: 6),
                    StreamBuilder<int>(
                      stream: cartCount,
                      builder: (context, snapshot) => Badge(
                        isLabelVisible: (snapshot.data ?? 0) > 0,
                        label: Text('${snapshot.data ?? 0}'),
                        backgroundColor: InventoryColors.ink,
                        child: IconButton(
                          tooltip: 'Open cart',
                          onPressed: openCart,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: InventoryColors.green,
                            minimumSize: const Size.square(44),
                          ),
                          icon: const Icon(
                            Icons.shopping_bag_outlined,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: TextField(
                    key: const ValueKey('shop-search'),
                    controller: search,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => FocusScope.of(context).unfocus(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: InventoryColors.ink,
                    ),
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: InventoryColors.line),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: InventoryColors.line),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(
                          color: InventoryColors.green,
                          width: 1.4,
                        ),
                      ),
                      hintText: 'Search name or barcode',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 22,
                        color: InventoryColors.muted,
                      ),
                      suffixIcon: search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () => setState(search.clear),
                              icon: const Icon(Icons.close_rounded, size: 20),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                InventoryFilters(
                  ids: ids,
                  records: records,
                  category: effectiveCategory,
                  onCategory: (value) => setState(() => category = value),
                  range: expiryRange,
                  onDate: () => _pickExpiryRange(context),
                  onClearDate: () => setState(() => expiryRange = null),
                  ascending: ascending,
                  onSort: () => setState(() => ascending = !ascending),
                  compact: true,
                ),
                const SizedBox(height: 16),
                ShopAssistantBanner(onTap: openAssistant),
                const SizedBox(height: 24),
                if (hasFilters) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${filtered.length} ${filtered.length == 1 ? 'product' : 'products'} found',
                          style: const TextStyle(
                            fontSize: 13,
                            color: InventoryColors.muted,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: resetFilters,
                        child: const Text('Clear filters'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (snapshot.hasError)
                  ShopStateCard(
                    icon: Icons.cloud_off_rounded,
                    title: 'Could not load products',
                    message: 'Check your connection and try again.',
                    actionLabel: 'Try again',
                    onAction: () {
                      widget.onRetry?.call();
                      setState(() {
                        inventory =
                            widget.inventoryStream ??
                            FirestoreService.instance.watchInventory();
                      });
                    },
                  )
                else if (!snapshot.hasData)
                  const ShopStateCard(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Loading products',
                    busy: true,
                  )
                else if (sellable.isEmpty)
                  const ShopStateCard(
                    icon: Icons.storefront_outlined,
                    title: 'New stock is on its way',
                    message:
                        'There are no products available to buy right now.',
                  )
                else if (filtered.isEmpty)
                  ShopStateCard(
                    icon: Icons.search_off_rounded,
                    title: 'No products found',
                    message: 'Try another search or clear your filters.',
                    actionLabel: 'Clear filters',
                    onAction: resetFilters,
                  )
                else ...[
                  if (promotions.isNotEmpty) ...[
                    ShopSectionTitle(
                      'On Promotion',
                      count: promotions.length,
                      subtitle: 'Good finds at a better price',
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height:
                          302 +
                          (MediaQuery.textScalerOf(context).scale(14) - 14)
                                  .clamp(0, 28) *
                              12,
                      child: ListView.separated(
                        key: const ValueKey('shop-promotions'),
                        scrollDirection: Axis.horizontal,
                        itemCount: promotions.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (_, index) => SizedBox(
                          width: promotions.length == 1
                              ? MediaQuery.sizeOf(context).width - 40
                              : MediaQuery.sizeOf(context).width < 350
                              ? 232
                              : 246,
                          child: _product(
                            promotions[index],
                            records,
                            featured: true,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                  ],
                  if (regular.isNotEmpty) ...[
                    ShopSectionTitle(
                      'Everyday Products',
                      count: regular.length,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ],
            ),
          ),
        ),
        if (snapshot.hasData && !snapshot.hasError && regular.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.separated(
              itemCount: regular.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, index) => _product(regular[index], records),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    );
  }

  Widget _product(
    InventoryBatch item,
    List<StoreCategory> records, {
    bool featured = false,
  }) => ShopProductCard(
    key: ValueKey('shop-product-${item.id}'),
    item: item,
    category: inventoryCategoryName(item.categoryId, records),
    featured: featured,
    busy: adding.contains(item.id),
    now: now,
    image: widget.imageProvider?.call(item),
    onOpen: () => openProduct(item),
    onAdd: () => _add(item),
  );

  bool _matches(InventoryBatch item, String effectiveCategory) {
    final query = search.text.trim().toLowerCase();
    if (!item.productName.toLowerCase().contains(query) &&
        !(item.barcode ?? '').toLowerCase().contains(query)) {
      return false;
    }
    if (effectiveCategory != 'all' && item.categoryId != effectiveCategory) {
      return false;
    }
    final range = expiryRange;
    if (range == null) return true;
    final day = DateUtils.dateOnly(item.expiryAt);
    return !day.isBefore(DateUtils.dateOnly(range.start)) &&
        !day.isAfter(DateUtils.dateOnly(range.end));
  }

  void resetFilters() => setState(() {
    search.clear();
    category = 'all';
    expiryRange = null;
  });
  Future<void> _pickExpiryRange(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final today = DateUtils.dateOnly(now);
    final selected = await showInventoryExpiryRange(
      context: context,
      firstDate: today,
      lastDate: DateTime(today.year + 10, 12, 31),
      initialDateRange: expiryRange,
    );
    if (selected != null && mounted) setState(() => expiryRange = selected);
  }

  Future<void> _add(InventoryBatch item) async {
    if (adding.contains(item.id)) return;
    setState(() => adding.add(item.id));
    try {
      if (widget.onAddToCart != null) {
        await widget.onAddToCart!(item);
      } else {
        await FirestoreService.instance.addToCart(item);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          inventoryFeedback(
            '${item.productName} added to cart',
            action: SnackBarAction(
              label: 'View cart',
              textColor: Colors.white,
              onPressed: openCart,
            ),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      final message = error is StateError
          ? error.message
          : 'Could not add this item. Please try again.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(inventoryFeedback(message, error: true));
    } finally {
      if (mounted) setState(() => adding.remove(item.id));
    }
  }

  Widget _bottomNav() => InventoryBottomNav(
    currentIndex: 0,
    items: [
      const NavItem(
        icon: Icons.storefront_outlined,
        activeIcon: Icons.storefront_rounded,
        label: 'Shop',
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
