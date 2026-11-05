import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/firestore_service.dart';
import '../services/store_session.dart';
import '../services/local_data_session.dart';
import '../widgets/catalogue_cache_notice.dart';
import '../widgets/local_database_shortcut.dart';
import 'local_database_screen.dart';
import '../widgets/glass_bottom_nav.dart' show NavItem;
import '../widgets/inventory_expiry_range.dart';
import '../widgets/inventory_ui.dart';
import '../widgets/shop_ui.dart';
import '../widgets/customer_ui.dart';
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
  final scroll = ScrollController();
  bool showTop = false;
  final savedView = SavedCatalogueView('shop');
  @override
  void initState() {
    super.initState();
    _restoreView();
    scroll.addListener(() {
      final next = scroll.offset > 380;
      if (next != showTop && mounted) setState(() => showTop = next);
    });
  }

  final adding = <String>{};
  late var inventory =
      widget.inventoryStream ?? FirestoreService.instance.watchInventory();
  late final categories =
      widget.categoriesStream ??
      FirestoreService.instance.watchCategoryRecords();
  late final cartCount =
      (widget.cartCountStream ??
              FirestoreService.instance.watchCart().map(
                (lines) =>
                    lines.fold<int>(0, (sum, line) => sum + line.quantity),
              ))
          .asBroadcastStream(onCancel: (subscription) => subscription.cancel());
  String category = 'all';
  DateTimeRange? expiryRange;
  bool ascending = true;
  Future<void> _restoreView() async {
    final value = await savedView.restore();
    if (mounted && value != null) {
      setState(() {
        category = value.category;
        ascending = value.ascending;
      });
    }
  }

  void _saveView() => savedView.save(category, ascending);
  DateTime get now => widget.now?.call() ?? DateTime.now();
  @override
  void dispose() {
    search.dispose();
    scroll.dispose();
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
        floatingActionButton: showTop
            ? FloatingActionButton.small(
                key: const ValueKey('shop-jump-top'),
                tooltip: 'Jump to top',
                backgroundColor: InventoryColors.green,
                foregroundColor: Colors.white,
                onPressed: () => scroll.animateTo(
                  0,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut,
                ),
                child: const Icon(Icons.keyboard_arrow_up_rounded),
              )
            : null,
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
          (item) =>
              item.promotionEnabled &&
              (item.promotionPriceCents != null || item.bundlePromotion),
        )
        .toList();
    final regular = filtered
        .where((item) => !promotions.contains(item))
        .toList();
    final columns = MediaQuery.textScalerOf(context).scale(15) > 20 ? 1 : 2;
    final promotionWidth = promotions.length == 1
        ? MediaQuery.sizeOf(context).width - 40
        : MediaQuery.sizeOf(context).width < 350
        ? 232.0
        : 246.0;
    final promotionFooterHeight = ShopProductCard.promotionFooterHeight(
      context,
      promotionWidth,
      promotions,
    );
    return CustomScrollView(
      key: const ValueKey('shop-scroll'),
      controller: scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(child: _header(context)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                      hintText: 'Search name',
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
                  onCategory: (value) {
                    setState(() => category = value);
                    _saveView();
                  },
                  range: expiryRange,
                  onDate: () => _pickExpiryRange(context),
                  onClearDate: () => setState(() => expiryRange = null),
                  ascending: ascending,
                  onSort: () {
                    setState(() => ascending = !ascending);
                    _saveView();
                  },
                  compact: true,
                  customerStyle: true,
                ),
                const CatalogueCacheNotice(horizontalMargin: 0),
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
                        child: const Text(
                          'Clear Filters',
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                          ),
                        ),
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
                    actionLabel: 'Clear Filters',
                    onAction: resetFilters,
                  )
                else ...[
                  if (promotions.isNotEmpty) ...[
                    ShopSectionTitle(
                      'On Promotion',
                      subtitle: 'Good finds at a better price',
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height:
                          350 +
                          (MediaQuery.textScalerOf(context).scale(14) - 14)
                                  .clamp(0, 28) *
                              12 +
                          promotionFooterHeight -
                          56,
                      child: ListView.separated(
                        key: const ValueKey('shop-promotions'),
                        scrollDirection: Axis.horizontal,
                        itemCount: promotions.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (_, index) => SizedBox(
                          width: promotionWidth,
                          child: _product(
                            promotions[index],
                            records,
                            featured: true,
                            footerHeight: promotionFooterHeight,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                  ],
                  if (regular.isNotEmpty) ...[
                    ShopSectionTitle('Everyday Products'),
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
              itemCount: (regular.length / columns).ceil(),
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, row) => IntrinsicHeight(
                child: columns == 1
                    ? _product(regular[row], records)
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _product(regular[row * 2], records)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: row * 2 + 1 < regular.length
                                ? _product(regular[row * 2 + 1], records)
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    );
  }

  Widget _header(BuildContext context) => InventoryHeader(
    title: 'Shop',
    storeName: StoreSession.instance.store?.name ?? 'Your store',
    storeIcon: LocalDatabaseShortcut(
      compact: true,
      onOpen: () async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const LocalDatabaseScreen()),
        );
      },
    ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        widget.chatButton ?? const StoreChatButton(inventoryStyle: true),
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
              icon: const Icon(Icons.shopping_bag_outlined, size: 22),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _product(
    InventoryBatch item,
    List<StoreCategory> records, {
    bool featured = false,
    double footerHeight = 56,
  }) => ShopProductCard(
    key: ValueKey('shop-product-${item.id}'),
    item: item,
    category: inventoryCategoryName(item.categoryId, records),
    featured: featured,
    footerHeight: footerHeight,
    busy: adding.contains(item.id),
    now: now,
    image: widget.imageProvider?.call(item),
    onOpen: () => openProduct(item),
    onAdd: () => _add(item),
  );

  bool _matches(InventoryBatch item, String effectiveCategory) {
    final query = search.text.trim().toLowerCase();
    if (!item.productName.toLowerCase().contains(query)) {
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
    _saveView();
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
      showAddedToCartFeedback(context, item.productName, onViewCart: openCart);
    } catch (error) {
      if (!mounted) return;
      final message = error is StateError
          ? error.message
          : 'Could not add this item. Please try again.';
      showCustomerFeedback(
        context,
        message.toString(),
        error: true,
        bottomMargin: 6,
      );
    } finally {
      if (mounted) setState(() => adding.remove(item.id));
    }
  }

  Widget _bottomNav() => CustomerBottomNav(
    cartCountStream: cartCount,
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
