import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_models.dart';
import '../services/firestore_service.dart';
import '../services/store_session.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_bottom_nav.dart';
import '../widgets/stockwise_ui.dart';
import 'cart_screen.dart';
import 'item_detail_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  String query = '';
<<<<<<< HEAD
  String category = 'all';
  DateTimeRange? expiryRange;
=======
>>>>>>> c329d3aa1357b4e87b680ad91ce3b6d980a28249

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
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
<<<<<<< HEAD
                  'Shop',
=======
                  'Promotion',
>>>>>>> c329d3aa1357b4e87b680ad91ce3b6d980a28249
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
<<<<<<< HEAD
              stream: FirestoreService.instance.watchInventory(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Could not load products: ${snapshot.error}'),
=======
              stream: FirestoreService.instance.watchPromotions(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Could not load promotions: ${snapshot.error}'),
>>>>>>> c329d3aa1357b4e87b680ad91ce3b6d980a28249
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
<<<<<<< HEAD
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
                final filtered = sellable.where(_matchesFilters).toList();
                final promotions = filtered
                    .where((item) => item.promotionEnabled)
                    .toList();
                final normal = filtered
                    .where((item) => !item.promotionEnabled)
                    .toList();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
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
=======
                final items = snapshot.data!
                    .where(
                      (item) => item.productName.toLowerCase().contains(
                        query.toLowerCase(),
                      ),
                    )
                    .toList();
                if (items.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Text(
                        'No active promotions in this store yet.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(18),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: .68,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) => _productCard(items[index]),
>>>>>>> c329d3aa1357b4e87b680ad91ce3b6d980a28249
                );
              },
            ),
          ),
          _bottomNav(context),
        ],
      ),
    ),
  );

<<<<<<< HEAD
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
          DropdownButtonFormField<String>(
            initialValue: categories.contains(category) ? category : 'all',
            decoration: const InputDecoration(
              labelText: 'Filter by category',
              prefixIcon: Icon(Icons.filter_alt_outlined),
            ),
            items: [
              const DropdownMenuItem(
                value: 'all',
                child: Text('All categories'),
              ),
              ...categories.map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(value.replaceAll('-', ' ')),
                ),
              ),
            ],
            onChanged: (value) => setState(() => category = value ?? 'all'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickExpiryRange,
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(
                    expiryRange == null
                        ? 'Filter by expiry date'
                        : '${DateFormat('dd/MM/yy').format(expiryRange!.start)} – ${DateFormat('dd/MM/yy').format(expiryRange!.end)}',
                  ),
                ),
              ),
              if (expiryRange != null)
                IconButton(
                  tooltip: 'Clear date filter',
                  onPressed: () => setState(() => expiryRange = null),
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
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
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: .68,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => _productCard(items[index]),
        ),
    ],
  );

  Future<void> _pickExpiryRange() async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
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
                  child: ProductArtwork(size: 100, imagePath: item.imagePath),
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
            const Spacer(),
            Text(
              item.productName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              'RM ${(item.sellingPriceCents / 100).toStringAsFixed(2)}',
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w900,
              ),
            ),
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

=======
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
                  child: ProductArtwork(size: 100, imagePath: item.imagePath),
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
            const Spacer(),
            Text(
              item.productName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              'RM ${(item.sellingPriceCents / 100).toStringAsFixed(2)}',
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w900,
              ),
            ),
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

>>>>>>> c329d3aa1357b4e87b680ad91ce3b6d980a28249
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
