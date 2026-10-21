import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../services/store_session.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_bottom_nav.dart';
import 'cart_screen.dart';
import 'home_screen.dart';
import 'items_screen.dart';
import 'login_screen.dart';
import 'orders_screen.dart';
import 'shop_screen.dart';
import 'store_gate_screen.dart';
<<<<<<< HEAD
import 'staff_management_screen.dart';
=======
>>>>>>> 831768e476072760b30a26d67dfa6f0d1864723f
import 'waste_analysis_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final session = StoreSession.instance;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 96,
              color: AppColors.primary,
              alignment: Alignment.center,
              child: const Text(
                'My Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<Map<String, dynamic>>(
                stream: FirestoreService.instance.watchUserProfile(),
                builder: (context, snapshot) {
                  final data = snapshot.data ?? const <String, dynamic>{};
                  final preferences = Map<String, dynamic>.from(
                    data['preferences'] as Map? ?? const {},
                  );
                  final enabled = preferences['expiryAlerts'] as bool? ?? true;
                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const CircleAvatar(
                        radius: 48,
                        backgroundColor: AppColors.primarySoft,
                        child: Icon(
                          Icons.person_rounded,
                          size: 46,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        data['displayName'] as String? ??
                            user?.displayName ??
                            'StockWise User',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        user?.email ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${session.store?.name ?? ''}  •  ${session.role.toUpperCase()}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Card(
                        child: Column(
                          children: [
                            SwitchListTile.adaptive(
                              secondary: const Icon(
                                Icons.notifications_outlined,
                              ),
                              title: const Text(
                                'Receive Notifications',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              subtitle: const Text(
                                'Expiry, promotion, and order updates',
                              ),
                              value: enabled,
                              onChanged: FirestoreService
                                  .instance
                                  .updateNotificationPreference,
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.swap_horiz_rounded),
                              title: const Text(
                                'Switch store',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => _switchStore(context),
                            ),
<<<<<<< HEAD
                            if (session.canManageMembers) ...[
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.groups_2_outlined),
                                title: const Text(
                                  'Manage store admins',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                subtitle: const Text(
                                  'Add staff access by email',
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const StaffManagementScreen(),
                                  ),
                                ),
                              ),
                            ],
=======
>>>>>>> 831768e476072760b30a26d67dfa6f0d1864723f
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                        ),
                        onPressed: () => _logout(context),
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('LOG OUT'),
                      ),
                    ],
                  );
                },
              ),
            ),
            _bottomNav(context),
          ],
        ),
      ),
    );
  }

  Future<void> _switchStore(BuildContext context) async {
    StoreSession.instance.clear();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const StoreGateScreen()),
      (_) => false,
    );
  }

  Future<void> _logout(BuildContext context) async {
    StoreSession.instance.clear();
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Widget _bottomNav(BuildContext context) {
    if (StoreSession.instance.canManage) {
      return GlassBottomNav(
        currentIndex: 4,
        items: [
          NavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'Home',
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            ),
          ),
          NavItem(
            icon: Icons.inventory_2_outlined,
            activeIcon: Icons.inventory_2_rounded,
            label: 'Items',
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ItemsScreen()),
            ),
          ),
          NavItem(
            icon: Icons.bar_chart_outlined,
            activeIcon: Icons.bar_chart_rounded,
            label: 'Report',
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const WasteAnalysisScreen()),
            ),
          ),
          NavItem(
            icon: Icons.shopping_cart_outlined,
            activeIcon: Icons.shopping_cart_rounded,
            label: 'Orders',
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const OrdersScreen()),
            ),
          ),
          const NavItem(
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
            label: 'Profile',
          ),
        ],
      );
    }
    return GlassBottomNav(
      currentIndex: 3,
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
            MaterialPageRoute(
              builder: (_) => const OrdersScreen(isAdmin: false),
            ),
          ),
        ),
        const NavItem(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: 'Profile',
        ),
      ],
    );
  }
}
