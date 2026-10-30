import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_models.dart';
import '../services/firestore_service.dart';
import '../services/store_session.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_bottom_nav.dart';
import '../widgets/expiry_date_filter.dart';
import '../widgets/inventory_expiry_range.dart';
import '../widgets/stockwise_ui.dart';
import '../widgets/product_price.dart';
import 'cart_screen.dart';
import 'item_detail_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'shopping_assistant_screen.dart';
import '../widgets/category_filter.dart';
import '../widgets/store_chat_button.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  String query = '';
  String category = 'all';
  DateTimeRange? expiryRange;
  bool expiryAscending = true;

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ShoppingAssistantScreen()),
      ),
      icon: const Icon(Icons.auto_awesome),
      label: const Text('Ask StockWise'),
    ),
    body: SafeArea(
      bottom: false,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        StoreSession.instance.store?.name ?? 'Store',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const StoreChatButton(),
                    StreamBuilder<List<CartLine>>(
                      stream: FirestoreService.instance.watchCart(),
                      builder: (context, snapshot) => Badge(
                        isLabelVisible: (snapshot.data?.length ?? 0) > 0,
                        label: Text('${snapshot.data?.length ?? 0}'),
                        child: IconButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CartScreen(),
                            ),
                          ),
                          icon: const Icon(
                            Icons.shopping_bag_outlined,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const Text(
                  'Shop',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Fresh stock, less waste',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 14),
                AppSearchField(
                  hint: 'Search products',
                  onChanged: (value) => setState(() => query = value),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<InventoryBatch>>(
              stream: FirestoreService.instance.watchInventory(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Could not load products: ${snapshot.error}'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final sellable = snapshot.data!
                    .where(
                      (item) =>
                          item.status == 'active' &&
                          item.availableQuantity > 0 &&
                          item.expiryAt.isAfter(DateTime.now()),
                    )
                    .toList();
                final categories =
                    sellable.map((item) => item.categoryId).toSet().toList()
                      ..sort();
                final filtered = sellable.where(_matchesFilters).toList()
                  ..sort(
                    (a, b) => expiryAscending
                        ? a.expiryAt.compareTo(b.expiryAt)
                        : b.expiryAt.compareTo(a.expiryAt),
                  );
                final promotions = filtered
                    .where((item) => item.promotionEnabled)
                    .toList();
                final normal = filtered
                    .where((item) => !item.promotionEnabled)
                    .toList();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 96),
                  children: [
                    _filters(categories),
                    const SizedBox(height: 20),
                    _section(
                      'Promotion Products',
                      promotions,
                      promotional: true,
                    ),
                    const SizedBox(height: 24),
                    _section('Normal Products', normal),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: SafeArea(top: false, child: _bottomNav(context)),
  );

  bool _matchesFilters(InventoryBatch item) {
    if (!item.productName.toLowerCase().contains(query.toLowerCase())) {
      return false;
    }
    if (category != 'all' && item.categoryId != category) return false;
    final range = expiryRange;
    if (range == null) return true;
    final day = DateTime(
      item.expiryAt.year,
      item.expiryAt.month,
      item.expiryAt.day,
    );
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(range.end.year, range.end.month, range.end.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  Widget _filters(List<String> categories) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          CategoryFilter(
            categoryIds: categories,
            selected: category,
            decoration: const InputDecoration(
              labelText: 'Filter by category',
              prefixIcon: Icon(Icons.filter_alt_outlined),
            ),
            onChanged: (value) => setState(() => category = value),
          ),
          const SizedBox(height: 10),
          ExpiryDateFilter(
            range: expiryRange,
            ascending: expiryAscending,
            onPickRange: _pickExpiryRange,
            onClearRange: () => setState(() => expiryRange = null),
            onToggleSort: () =>
                setState(() => expiryAscending = !expiryAscending),
          ),
        ],
      ),
    ),
  );

  Widget _section(
    String title,
    List<InventoryBatch> items, {
    bool promotional = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          StatusPill(
            '${items.length}',
            color: promotional ? AppColors.warning : AppColors.primaryDark,
          ),
        ],
      ),
      const SizedBox(height: 10),
      if (items.isEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text(
                promotional
                    ? 'No promotion products match your filters.'
                    : 'No normal products match your filters.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        )
      else
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent:
                280 +
                (MediaQuery.textScalerOf(context).scale(14) - 14).clamp(0, 28) *
                    6,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => _productCard(items[index]),
        ),
    ],
  );

  Future<void> _pickExpiryRange() async {
    final now = DateTime.now();
    final selected = await showInventoryExpiryRange(
      context: context,
      firstDate: DateTime(now.year),
      lastDate: DateTime(now.year + 10),
      initialDateRange: expiryRange,
    );
    if (selected != null) setState(() => expiryRange = selected);
  }

  Widget _productCard(InventoryBatch item) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ProductArtwork(size: 160, imagePath: item.imagePath),
                ),
                if (item.promotionEnabled)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.danger.withValues(alpha: .2),
                              Colors.transparent,
                              Colors.transparent,
                            ],
                            stops: const [0, .55, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (item.promotionEnabled)
                  const Positioned(
                    left: 7,
                    top: 0,
                    child: IgnorePointer(child: _PromotionRibbon()),
                  ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: IconButton.filledTonal(
                    tooltip: 'Add to cart',
                    onPressed: () => _add(item),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.warning,
                    ),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.productName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            ProductPrice(item: item),
            const SizedBox(height: 4),
            Text(
              'Exp: ${DateFormat('dd/MM/yyyy').format(item.expiryAt)}',
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
            Text(
              '${item.availableQuantity} available',
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _add(InventoryBatch item) async {
    try {
      await FirestoreService.instance.addToCart(item);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${item.productName} added to cart')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Widget _bottomNav(BuildContext context) => GlassBottomNav(
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

class _PromotionRibbon extends StatelessWidget {
  const _PromotionRibbon();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Promotion',
    child: ExcludeSemantics(
      child: ClipPath(
        clipper: const _PromotionRibbonClipper(),
        child: const SizedBox(
          width: 28,
          height: 92,
          child: ColoredBox(
            color: AppColors.danger,
            child: Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: RotatedBox(
                    quarterTurns: 1,
                    child: Text(
                      'PROMO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _PromotionRibbonClipper extends CustomClipper<Path> {
  const _PromotionRibbonClipper();

  @override
  Path getClip(Size size) => Path()
    ..lineTo(size.width, 0)
    ..lineTo(size.width, size.height)
    ..lineTo(size.width / 2, size.height - 10)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(_PromotionRibbonClipper oldClipper) => false;
}
