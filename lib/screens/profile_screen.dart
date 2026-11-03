import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/firestore_service.dart';
import '../services/store_session.dart';
import '../services/profile_fields.dart';
import '../services/address_book_service.dart';
import '../widgets/glass_bottom_nav.dart';
import '../widgets/store_chat_button.dart';
import '../widgets/inventory_ui.dart';
import '../widgets/customer_ui.dart';
import '../widgets/profile_ui.dart';
import '../services/store_chat_service.dart';
import '../services/password_change_service.dart';
import '../services/store_fields.dart';
import '../models/app_models.dart';
import 'create_store_dialog.dart';
import 'cart_screen.dart';
import 'address_book_screen.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';
import 'home_screen.dart';
import 'items_screen.dart';
import 'auth_gate.dart';
import 'orders_screen.dart';
import 'shop_screen.dart';
import 'store_gate_screen.dart';
import 'staff_management_screen.dart';
import 'delivery_fee_screen.dart';
import '../services/push_service.dart';
import 'waste_analysis_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.profileStream,
    this.accountEmail,
    this.onSave,
    this.pickPhoto,
    this.addressRepository,
    this.chatRepository,
    this.onChangePassword,
    this.shopStream,
    this.onSaveShop,
    this.onNotificationPreference,
    this.onSignOut,
    this.onSignedOut,
  });
  final Stream<Map<String, dynamic>>? profileStream;
  final String? accountEmail;
  final ProfileSaver? onSave;
  final Future<XFile?> Function()? pickPhoto;
  final AddressBookRepository? addressRepository;
  final StoreChatRepository? chatRepository;
  final PasswordChanger? onChangePassword;
  final Stream<StoreInfo?>? shopStream;
  final StoreUpdater? onSaveShop;
  final Future<void> Function(bool)? onNotificationPreference;
  final Future<void> Function()? onSignOut;
  final VoidCallback? onSignedOut;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final scroll = ScrollController();
  late final profile =
      widget.profileStream ?? FirestoreService.instance.watchUserProfile();
  late final shop =
      widget.shopStream ?? FirestoreService.instance.watchSelectedStore();
  bool preferenceSaving = false, loggingOut = false;
  bool? preferenceValue;
  String? preferenceError, logoutError;
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => InventoryTheme(
    child: Builder(
      builder: (context) {
        final email =
            widget.accountEmail ??
            FirebaseAuth.instance.currentUser?.email ??
            '';
        return PopScope(
          canPop: !loggingOut,
          child: Scaffold(
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  const InventoryHeader(title: 'Your Profile', enlarged: true),
                  Expanded(
                    child: StreamBuilder<Map<String, dynamic>>(
                      stream: profile,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const SingleChildScrollView(
                            child: ProfileEmpty(
                              'Could not load your profile',
                              body: 'Please reopen this page.',
                            ),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }
                        if (StoreSession.instance.isOwner) {
                          return StreamBuilder<StoreInfo?>(
                            stream: shop,
                            initialData: StoreSession.instance.store,
                            builder: (context, store) =>
                                content(context, snapshot.data!, email, store),
                          );
                        }
                        return content(context, snapshot.data!, email, null);
                      },
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              child: AbsorbPointer(
                absorbing: loggingOut,
                child: _bottomNav(context),
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget content(
    BuildContext context,
    Map<String, dynamic> data,
    String email,
    AsyncSnapshot<StoreInfo?>? shopData,
  ) {
    final session = StoreSession.instance;
    final preferences = Map<String, dynamic>.from(
      data['preferences'] as Map? ?? const {},
    );
    final enabled = preferences['expiryAlerts'] as bool? ?? true;
    if (!preferenceSaving && preferenceValue == enabled) preferenceValue = null;
    final name = (data['displayName'] as String?)?.trim();
    final store = shopData?.data ?? session.store;
    return ListView(
      key: const ValueKey('profile-scroll'),
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        ProfileIdentity(
          key: const ValueKey('profile-identity'),
          name: name?.isNotEmpty == true ? name! : 'StockWise User',
          email: email,
          phone: data['phoneNumber'] as String?,
          photo: data['photoPath'] as String?,
          role: '${session.role[0].toUpperCase()}${session.role.substring(1)}',
          storeName: store?.name ?? 'StockWise',
        ),
        if (session.isOwner) ...[
          const SizedBox(height: 16),
          shopDetails(shopData!),
        ],
        const ProfileSection('Your Account'),
        ProfilePanel(
          padding: 0,
          child: Column(
            children: [
              ProfileAction(
                key: const ValueKey('profile-edit-action'),
                label: 'Edit Profile',
                icon: Icons.edit_outlined,
                onTap: loggingOut
                    ? null
                    : () => _editProfile(context, data, email),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ProfileAction(
                key: const ValueKey('profile-password-action'),
                label: 'Change Password',
                icon: Icons.lock_outline_rounded,
                onTap: loggingOut ? null : () => _changePassword(context),
              ),
            ],
          ),
        ),
        ProfileSection(
          session.canManage ? 'Store And Preferences' : 'Store and Preferences',
        ),
        ProfilePanel(
          padding: 0,
          child: Column(
            children: [
              if (session.canManageMembers || !session.canManage) ...[
                ProfileAction(
                  label: session.canManageMembers
                      ? 'Customer Messages'
                      : 'Chat with admin',
                  icon: Icons.chat_bubble_outline_rounded,
                  onTap: loggingOut
                      ? null
                      : () => openStoreChat(
                          context,
                          repository: widget.chatRepository,
                        ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
              ],
              if (!session.canManage) ...[
                ProfileAction(
                  label: 'Address Book',
                  subtitle: 'Saved delivery addresses',
                  icon: Icons.contact_mail_outlined,
                  onTap: loggingOut
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddressBookScreen(
                              initialName: data['displayName'] as String? ?? '',
                              initialPhone:
                                  data['phoneNumber'] as String? ?? '',
                              repository: widget.addressRepository,
                            ),
                          ),
                        ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
              ],
              if (session.canManageMembers) ...[
                const Divider(height: 1, indent: 16, endIndent: 16),
                ProfileAction(
                  label: 'Manage Store Admins',
                  subtitle: 'Add staff access by email',
                  icon: Icons.groups_2_outlined,
                  onTap: loggingOut
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StaffManagementScreen(),
                          ),
                        ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ProfileAction(
                  label: 'Manage Delivery Fee',
                  icon: Icons.local_shipping_outlined,
                  onTap: loggingOut
                      ? null
                      : () async {
                          final saved = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DeliveryFeeScreen(),
                            ),
                          );
                          if (saved == true && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              inventoryFeedback('Delivery fees updated'),
                            );
                          }
                        },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.notifications_outlined,
                      size: 21,
                      color: InventoryColors.green,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Receive Notifications',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            session.canManage
                                ? 'Expiry and order updates'
                                : 'Promotion and order updates',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.4,
                              color: InventoryColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      key: const ValueKey('profile-notifications'),
                      value: preferenceValue ?? enabled,
                      activeTrackColor: InventoryColors.green,
                      onChanged: preferenceSaving || loggingOut
                          ? null
                          : changePreference,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              if (session.canManage) ...[
                _ReportEmailPreference(
                  disabled: loggingOut,
                  stream: widget.profileStream != null
                      ? Stream.value(true)
                      : FirestoreService.instance.watchReportEmailPreference(),
                  save: widget.profileStream != null
                      ? (enabled) async {}
                      : FirestoreService.instance.setReportEmailPreference,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
              ],
              ProfileAction(
                label: 'Switch Store',
                icon: Icons.swap_horiz_rounded,
                onTap: loggingOut ? null : () => _switchStore(context),
              ),
            ],
          ),
        ),
        if (preferenceSaving) ...[
          const SizedBox(height: 16),
          const ProfileNotice('Saving notification preference...', busy: true),
        ],
        if (preferenceError != null) ...[
          const SizedBox(height: 16),
          ProfileNotice(preferenceError!, error: true),
        ],
        if (logoutError != null) ...[
          const SizedBox(height: 16),
          ProfileNotice(logoutError!, error: true),
        ],
        const SizedBox(height: 22),
        InventoryButton(
          key: const ValueKey('profile-logout'),
          label: loggingOut ? 'Logging out...' : 'Log out',
          icon: Icons.logout_rounded,
          danger: true,
          busy: loggingOut,
          onPressed: loggingOut ? null : () => _logout(context),
        ),
      ],
    );
  }

  Widget shopDetails(AsyncSnapshot<StoreInfo?> snapshot) {
    if (snapshot.hasError) {
      return const ProfilePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Store Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 14),
            ProfileNotice(
              'Could not load your shop details. Please reopen this page.',
              error: true,
            ),
          ],
        ),
      );
    }
    final store = snapshot.data;
    if (store == null) {
      return const ProfilePanel(child: Text('This shop no longer exists.'));
    }
    return ProfilePanel(
      key: const ValueKey('profile-shop-details'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.storefront_outlined,
                color: InventoryColors.green,
                size: 22,
              ),
              SizedBox(width: 10),
              Text(
                'Store Details',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            store.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 18,
                color: InventoryColors.muted,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  store.shopAddress.isEmpty
                      ? 'No shop address saved yet.'
                      : store.shopAddress,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: InventoryColors.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(
                Icons.schedule_outlined,
                size: 18,
                color: InventoryColors.muted,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Operating hours: ${store.operatingHours.label}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: InventoryColors.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          InventoryButton(
            label: 'Edit Store',
            icon: Icons.edit_outlined,
            soft: true,
            onPressed: loggingOut ? null : () => _editShop(store),
          ),
        ],
      ),
    );
  }

  Future<void> changePreference(bool value) async {
    if (preferenceSaving) return;
    setState(() {
      preferenceValue = value;
      preferenceSaving = true;
      preferenceError = null;
    });
    try {
      await (widget.onNotificationPreference ??
          FirestoreService.instance.updateNotificationPreference)(value);
    } catch (_) {
      if (mounted) {
        setState(() {
          preferenceValue = null;
          preferenceError = 'Could not update notifications. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => preferenceSaving = false);
    }
  }

  Future<void> _editShop(StoreInfo store) async {
    final updated = await showDialog<StoreInfo>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateStoreDialog(
        initialStore: store,
        onCreate: widget.onSaveShop == null
            ? null
            : ({required name, required address}) => widget.onSaveShop!(
                storeId: store.id,
                name: name,
                address: address,
              ),
      ),
    );
    if (updated == null || !mounted) return;
    final session = StoreSession.instance;
    if (session.storeId != store.id || !session.isOwner) return;
    session.select(updated, role: session.role);
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(inventoryFeedback('Shop details updated'));
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
      ).showSnackBar(inventoryFeedback('Profile updated'));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(inventoryFeedback('Password changed successfully'));
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
    if (loggingOut) return;
    final confirmed = await showProfileConfirmation(
      context: context,
      title: 'Log out of StockWise?',
      message:
          'You will return to the sign-in page. Your saved account and store information will stay available.',
      action: 'Log out',
      cancel: 'Stay signed in',
      danger: true,
    );
    if (!confirmed || !context.mounted) return;
    setState(() {
      loggingOut = true;
      logoutError = null;
    });
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Dialog(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Logging out',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: InventoryColors.ink,
                  ),
                ),
                SizedBox(height: 22),
                ProfileNotice(
                  'Please wait while StockWise signs you out.',
                  busy: true,
                ),
              ],
            ),
          ),
        ),
      ),
    ).ignore();
    try {
      if (widget.onSignOut == null) await PushService.instance.detach();
      await (widget.onSignOut ?? FirebaseAuth.instance.signOut)();
      if (!context.mounted) return;
      navigator.pop();
      StoreSession.instance.clear();
      if (widget.onSignedOut != null) {
        widget.onSignedOut!();
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (_) => false,
        );
      }
    } catch (_) {
      if (context.mounted) {
        navigator.pop();
        setState(() => logoutError = 'Could not sign out. Please try again.');
      }
    } finally {
      if (mounted) setState(() => loggingOut = false);
    }
  }

  Widget _bottomNav(BuildContext context) {
    if (StoreSession.instance.canManage) {
      return InventoryBottomNav(
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
            label: 'Inventory',
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
    return CustomerBottomNav(
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

class _ReportEmailPreference extends StatefulWidget {
  const _ReportEmailPreference({
    required this.stream,
    required this.save,
    required this.disabled,
  });
  final Stream<bool> stream;
  final Future<void> Function(bool) save;
  final bool disabled;
  @override
  State<_ReportEmailPreference> createState() => _ReportEmailPreferenceState();
}

class _ReportEmailPreferenceState extends State<_ReportEmailPreference> {
  bool saving = false;
  bool? value;
  String? error;
  @override
  Widget build(BuildContext context) => StreamBuilder<bool>(
    stream: widget.stream,
    builder: (context, snapshot) => Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              const Icon(
                Icons.mail_outline_rounded,
                size: 21,
                color: InventoryColors.green,
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Receive Reports via Email',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              Switch(
                value: value ?? snapshot.data ?? true,
                onChanged: saving || widget.disabled || snapshot.hasError
                    ? null
                    : (enabled) async {
                        setState(() {
                          value = enabled;
                          saving = true;
                          error = null;
                        });
                        try {
                          await widget.save(enabled);
                        } catch (_) {
                          if (mounted) {
                            setState(() {
                              value = null;
                              error =
                                  'Could not update report email preference.';
                            });
                          }
                        } finally {
                          if (mounted) setState(() => saving = false);
                        }
                      },
              ),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: ProfileNotice(error!, error: true),
          ),
      ],
    ),
  );
}
