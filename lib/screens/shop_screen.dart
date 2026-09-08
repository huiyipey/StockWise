import 'package:flutter/material.dart';
import '../widgets/glass_bottom_nav.dart';
import 'profile_screen.dart';
import 'cart_screen.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Stack(
                  children: [
                    _buildHeader(),
                    Padding(
                      padding: const EdgeInsets.only(top: 155),
                      child: _buildContent(),
                    ),
                  ],
                ),
              ),
            ),
            _buildBottomNav(context),
          ],
        ),
      ),
    );
  }

  static Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 310,
      padding: const EdgeInsets.fromLTRB(24, 44, 24, 0),
      decoration: const BoxDecoration(color: Color(0xFF7FAA75)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'SHOP',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                ),
              ),
            ),
          ),
          const Spacer(),
          const Text(
            'Promotion',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fresh groceries at your fingertips',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static Widget _buildContent() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 100),
      child: _ProductGrid(),
    );
  }

  static Widget _buildBottomNav(BuildContext context) {
    return GlassBottomNav(
      currentIndex: 0,
      activeColor: const Color(0xFF7FAA75),
      items: [
        const NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
        NavItem(icon: Icons.shopping_cart_outlined, activeIcon: Icons.shopping_cart, label: 'Cart', badgeCount: 3, onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
        }),
        const NavItem(icon: Icons.history_outlined, activeIcon: Icons.history, label: 'History'),
        NavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile', onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
        }),
      ],
    );
  }
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = 16.0;
        final cardWidth = (constraints.maxWidth - gap) / 2;
        return Wrap(
          alignment: WrapAlignment.center,
          runSpacing: 18,
          spacing: gap,
          children: List.generate(4, (_) => _buildProductCard(cardWidth)),
        );
      },
    );
  }

  static Widget _buildProductCard(double width) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 10,
            right: 10,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF39C12).withValues(alpha: 0.12),
                  border: Border.all(color: const Color(0xFFF39C12), width: 2),
                ),
                child: const Center(
                  child: Text(
                    '+',
                    style: TextStyle(
                      color: Color(0xFFF39C12),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 22, 14, 18),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Icon(Icons.inventory_2_outlined,
                        size: 28, color: Color(0xFFBBBBBB)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Product Name',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'RM 20.50',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF555555),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Exp: DD/MM/YYYY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFB8860B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
