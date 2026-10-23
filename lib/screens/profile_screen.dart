import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/firestore_service.dart';
import '../services/store_session.dart';
import '../services/profile_fields.dart';
import '../services/address_book_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_bottom_nav.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/store_chat_button.dart';
import '../services/store_chat_service.dart';
import '../services/password_change_service.dart';
import 'cart_screen.dart';
import 'address_book_screen.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';
import 'home_screen.dart';
import 'items_screen.dart';
import 'login_screen.dart';
import 'orders_screen.dart';
import 'shop_screen.dart';
import 'store_gate_screen.dart';
import 'staff_management_screen.dart';
import 'waste_analysis_screen.dart';

class ProfileScreen extends StatefulWidget {
  final Stream<Map<String, dynamic>>? profileStream;
  final String? accountEmail;
  final ProfileSaver? onSave;
  final Future<XFile?> Function()? pickPhoto;
  final AddressBookRepository? addressRepository;
  final StoreChatRepository? chatRepository;
  final PasswordChanger? onChangePassword;

  const ProfileScreen({
    super.key,
    this.profileStream,
    this.accountEmail,
    this.onSave,
    this.pickPhoto,
    this.addressRepository,
    this.chatRepository,
    this.onChangePassword,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final scroll = ScrollController();
  late final profile =
      widget.profileStream ?? FirestoreService.instance.watchUserProfile();

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email =
        widget.accountEmail ?? FirebaseAuth.instance.currentUser?.email ?? '';
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
                stream: profile,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Could not load your profile. Please reopen this page.',
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final data = snapshot.data ?? const <String, dynamic>{};
                  final preferences = Map<String, dynamic>.from(
                    data['preferences'] as Map? ?? const {},
                  );
                  final enabled = preferences['expiryAlerts'] as bool? ?? true;
                  return ListView(
                    controller: scroll,
                    padding: const EdgeInsets.all(20),
                    children: [
                      ProfileAvatar(photoPath: data['photoPath'] as String?),
                      const SizedBox(height: 14),
                      Text(
                        data['displayName'] as String? ?? 'StockWise User',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        email,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      if ((data['phoneNumber'] as String? ?? '').isNotEmpty)
                        Text(
                          data['phoneNumber'] as String,
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
                            ListTile(
                              leading: const Icon(Icons.edit_outlined),
                              title: const Text(
                                'Edit profile',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => _editProfile(context, data, email),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.lock_outline_rounded),
                              title: const Text(
                                'Change password',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => _changePassword(context),
                            ),
                            const Divider(height: 1),
                            if (session.canManageMembers ||
                                !session.canManage) ...[
                              ListTile(
                                leading: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                ),
                                title: Text(
                                  session.canManageMembers
                                      ? 'Customer messages'
                                      : 'Chat with admin',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                ),
                                onTap: () => openStoreChat(
                                  context,
                                  repository: widget.chatRepository,
                                ),
                              ),
                              const Divider(height: 1),
                            ],
                            if (!session.canManage) ...[
                              ListTile(
                                leading: const Icon(
                                  Icons.contact_mail_outlined,
                                ),
                                title: const Text(
                                  'Address book',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                subtitle: const Text(
                                  'Saved delivery addresses',
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddressBookScreen(
                                      initialName:
                                          data['displayName'] as String? ?? '',
                                      initialPhone:
                                          data['phoneNumber'] as String? ?? '',
                                      repository: widget.addressRepository,
                                    ),
                                  ),
                                ),
                              ),
                              const Divider(height: 1),
                            ],
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
                              onChanged: (value) => FirestoreService.instance
                                  .updateNotificationPreference(value),
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

  Future<void> _editProfile(
    BuildContext context,
    Map<String, dynamic> data,
    String email,
  ) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          displayName: data['displayName'] as String? ?? '',
          phoneNumber: data['phoneNumber'] as String? ?? '',
          photoPath: data['photoPath'] as String?,
          email: email,
          onSave: widget.onSave,
          pickPhoto: widget.pickPhoto,
        ),
      ),
    );
    if (saved == true && context.mounted) {
      if (scroll.hasClients) scroll.jumpTo(0);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ChangePasswordScreen(onChangePassword: widget.onChangePassword),
      ),
    );
    if (changed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully')),
      );
    }
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
