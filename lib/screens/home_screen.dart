import 'package:flutter/material.dart';
import '../widgets/glass_bottom_nav.dart';
import 'add_item_screen.dart';
import 'item_detail_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'waste_analysis_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(context),
                  _buildContent(context),
                ],
              ),
            ),
            _buildBottomNav(context),
          ],
        ),
      ),
    );
  }

  static Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 320,
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 0),
      decoration: const BoxDecoration(color: Color(0xFF79AD74)),
      child: Stack(
        children: [
          const Positioned(
            top: 0,
            left: 28,
            child: Text(
              'StockWise',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 24,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: Color(0xFFF5D94C),
                  size: 28,
                ),
              ),
            ),
          ),
          const Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  'Welcome Back!',
                  style: TextStyle(
                    color: Color(0xFF444444),
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Quick glance at your stock',
                  style: TextStyle(
                    color: Color(0xFF5B5B5B),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _buildExpiringSoonCard(),
          const SizedBox(height: 22),
          const Text(
            'Expiring Stock',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          _buildStockCard(context),
          const SizedBox(height: 70),
          _buildAddButton(context),
        ],
      ),
    );
  }

  static Widget _buildExpiringSoonCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.access_time, size: 18, color: Color(0xFFF7A623)),
              ),
              const SizedBox(width: 10),
              const Text(
                'Expiring Soon',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCircleIndicator('2 days', const Color(0xFFF44336), const Color(0xFFFFEBEE)),
              _buildCircleIndicator('3 days', const Color(0xFFF7A623), const Color(0xFFFFF8E1)),
              _buildCircleIndicator('7 days', const Color(0xFF7AC943), const Color(0xFFE8F5E9)),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildCircleIndicator(String label, Color borderColor, Color bgColor) {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor,
            border: Border.all(color: borderColor, width: 6),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF555555),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Category',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF555555),
          ),
        ),
      ],
    );
  }

  static Widget _buildStockCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ItemDetailScreen()),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F8F0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Icon(Icons.inventory_2_outlined,
                    size: 26, color: Color(0xFF75A972)),
              ),
            ),
            const SizedBox(width: 18),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Name',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF444444),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Exp: DD/MM/YYYY\nQty: 1',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF888888),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Text(
                '10 days',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF75A972),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildAddButton(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddItemScreen()),
          );
        },
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF79AD74),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF79AD74).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.add, color: Colors.white, size: 36),
          ),
        ),
      ),
    );
  }

  static Widget _buildBottomNav(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: GlassBottomNav(
        currentIndex: 0,
        activeColor: const Color(0xFF5B4B9A),
        items: [
          const NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
          NavItem(icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2, label: 'Items', onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AddItemScreen()));
          }),
          NavItem(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart, label: 'Report', onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const WasteAnalysisScreen()));
          }),
          NavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile', onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
          }),
        ],
      ),
    );
  }
}
