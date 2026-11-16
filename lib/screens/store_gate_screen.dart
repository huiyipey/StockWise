import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../models/store_role.dart';
import '../services/firestore_service.dart';
import '../services/store_fields.dart';
import '../services/store_session.dart';
import '../widgets/auth_ui.dart';
import '../widgets/store_ui.dart';
import '../widgets/store_created_notice.dart';
import '../widgets/profile_ui.dart' show showProfileConfirmation;
import '../widgets/inventory_ui.dart';
import 'create_store_dialog.dart';
import 'home_screen.dart';
import 'shop_screen.dart';
import 'profile_screen.dart';

// Choose a shop and apply its current account role.
class StoreGateScreen extends StatefulWidget {
  const StoreGateScreen({
    super.key,
    this.storesStream,
    this.membershipsStream,
    this.accountEmail,
    this.onRefresh,
    this.onCreate,
    this.onSelect,
    this.selectedStoreBuilder,
  });
  final Stream<List<StoreInfo>>? storesStream;
  final Stream<List<StoreMembership>>? membershipsStream;
  final String? accountEmail;
  final Future<void> Function()? onRefresh;
  final StoreCreator? onCreate;
  final void Function(StoreInfo store, String role)? onSelect;
  final Widget Function(BuildContext, StoreInfo, String)? selectedStoreBuilder;

  @override
  State<StoreGateScreen> createState() => _StoreGateScreenState();
}

// Manage the store gate screen values and actions.
class _StoreGateScreenState extends State<StoreGateScreen> {
  // Keep this component's values, selections, and request state.
  bool creating = false, checkingInvites = false, selecting = false;
  final search = TextEditingController();
  String query = '';
  String? deleting;
  StreamSubscription<List<StoreInfo>>? _storesSubscription;
  StreamSubscription<List<StoreMembership>>? _membershipsSubscription;
  List<StoreInfo>? _stores;
  List<StoreMembership>? _memberships;
  bool _storesFailed = false, _membershipsFailed = false;
  int _streamVersion = 0;

  // Set up the initial values and screen state.
  @override
  void initState() {
    super.initState();
    _streams();
  }

  // Refresh values when the parent supplies new data.
  @override
  void didUpdateWidget(covariant StoreGateScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.storesStream != oldWidget.storesStream ||
        widget.membershipsStream != oldWidget.membershipsStream) {
      _streams();
    }
  }

  // Listen for shop details and membership changes.
  void _streams() {
    unawaited(_storesSubscription?.cancel());
    unawaited(_membershipsSubscription?.cancel());
    final version = ++_streamVersion;
    _stores = null;
    _memberships = null;
    _storesFailed = false;
    _membershipsFailed = false;
    _storesSubscription =
        (widget.storesStream ?? FirestoreService.instance.watchStores()).listen(
          (stores) {
            if (!mounted || version != _streamVersion) return;
            final session = StoreSession.instance;
            final removed =
                session.storeId != null &&
                (_stores?.any((store) => store.id == session.storeId) ??
                    false) &&
                !stores.any((store) => store.id == session.storeId);
            setState(() {
              _stores = stores;
              _storesFailed = false;
            });
            if (removed) {
              session.clear();
              _closeStoreRoutes('This store is no longer available.');
            }
          },
          onError: (Object error) {
            if (!mounted || version != _streamVersion) return;
            setState(() => _storesFailed = true);
          },
        );
    _membershipsSubscription =
        (widget.membershipsStream ??
                FirestoreService.instance.watchMyMemberships())
            .listen(
              (memberships) {
                if (!mounted || version != _streamVersion) return;
                setState(() {
                  _memberships = memberships;
                  _membershipsFailed = false;
                });
                final session = StoreSession.instance;
                if (session.reconcileMemberships(memberships)) {
                  _closeStoreRoutes(
                    session.canManage
                        ? 'You now have admin access to this store.'
                        : 'Your admin access to this store has been removed.',
                  );
                }
              },
              onError: (Object error) {
                if (!mounted || version != _streamVersion) return;
                setState(() => _membershipsFailed = true);
                if (StoreSession.instance.canManage) {
                  StoreSession.instance.clear();
                  _closeStoreRoutes(
                    'Could not confirm admin access. Please reopen your store.',
                  );
                }
              },
            );
  }

  // Close admin pages after access or shop availability changes.
  void _closeStoreRoutes(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });
  }

  // Release controllers, timers, and subscriptions held by this component.
  @override
  void dispose() {
    search.dispose();
    unawaited(_storesSubscription?.cancel());
    unawaited(_membershipsSubscription?.cancel());
    super.dispose();
  }

  // Accept valid pending invitations for the signed-in account.
  Future<void> _checkInvites() async {
    if (checkingInvites) return;
    setState(() => checkingInvites = true);
    try {
      if (widget.onRefresh != null) {
        await widget.onRefresh!();
      } else {
        await FirebaseAuth.instance.currentUser!.reload();
        await FirebaseAuth.instance.currentUser!.getIdToken(true);
        await FirestoreService.instance.ensureUserProfile();
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Admin access refreshed')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not refresh access. Try again shortly.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => checkingInvites = false);
    }
  }

  // Build the store gate screen layout.
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: StoreSession.instance,
    builder: (context, _) {
      final session = StoreSession.instance;
      final selectedStore = session.store;
      if (selectedStore != null && _memberships != null) {
        return widget.selectedStoreBuilder?.call(
              context,
              selectedStore,
              session.role,
            ) ??
            (session.canManage ? const HomeScreen() : const ShopScreen());
      }
      final roles = <String, String>{};
      for (final member in _memberships ?? <StoreMembership>[]) {
        if (member.isAdmin) roles[member.storeId] = 'admin';
      }
      return Scaffold(
        backgroundColor: AuthColors.background,
        body: SafeArea(
          child: _content(
            _stores ?? const [],
            roles,
            failed: _storesFailed || _membershipsFailed,
            loading: _stores == null || _memberships == null,
          ),
        ),
      );
    },
  );

  // Filter the visible stores without changing their membership data.
  Widget _content(
    List<StoreInfo> stores,
    Map<String, String> roles, {
    required bool failed,
    required bool loading,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final cardHeight = math.max(420.0 * scale, constraints.maxHeight - 260);
      final term = query.trim().toLowerCase();
      final visibleStores = stores
          .where((store) => store.name.toLowerCase().contains(term))
          .toList();
      return SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 46, 20, 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Show the StockWise logo at the shared auth size.
                const AuthBrand(),
                const SizedBox(height: 48),
                Container(
                  height: cardHeight,
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Choose a Store',
                        style: TextStyle(
                          color: AuthColors.ink,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        !failed && !loading && stores.isEmpty
                            ? 'Start with your first store.'
                            : 'Select a store to continue.',
                        style: const TextStyle(
                          color: AuthColors.muted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: failed
                            ? _errorState()
                            : loading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: AuthColors.green,
                                ),
                              )
                            : stores.isEmpty
                            ? _emptyState()
                            : Column(
                                children: [
                                  TextField(
                                    key: const ValueKey('store-search'),
                                    controller: search,
                                    enabled: !creating && !selecting,
                                    textAlignVertical: TextAlignVertical.center,
                                    textInputAction: TextInputAction.search,
                                    style: const TextStyle(
                                      color: AuthColors.ink,
                                      fontSize: 14,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Search stores',
                                      filled: true,
                                      fillColor: AuthColors.background,
                                      prefixIcon: const Icon(
                                        Icons.search_rounded,
                                        color: AuthColors.muted,
                                      ),
                                      suffixIcon: query.isEmpty
                                          ? null
                                          : IconButton(
                                              tooltip: 'Clear store search',
                                              onPressed: _clearSearch,
                                              icon: const Icon(
                                                Icons.close_rounded,
                                              ),
                                            ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                          color: AuthColors.border,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                          color: AuthColors.border,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                          color: AuthColors.green,
                                          width: 1.5,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 14,
                                          ),
                                    ),
                                    onChanged: (value) =>
                                        setState(() => query = value),
                                  ),
                                  const SizedBox(height: 18),
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'AVAILABLE STORES',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AuthColors.muted,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: visibleStores.isEmpty
                                        ? _noMatches()
                                        : ListView.separated(
                                            padding: EdgeInsets.zero,
                                            itemCount: visibleStores.length,
                                            separatorBuilder: (_, index) =>
                                                const SizedBox(height: 12),
                                            itemBuilder: (_, index) =>
                                                _storeTile(
                                                  visibleStores[index],
                                                  roles[visibleStores[index]
                                                          .id] ??
                                                      'customer',
                                                ),
                                          ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 24),
                      StorePrimaryButton(
                        label: 'Create a Store',
                        busy: creating,
                        onPressed: failed || loading || selecting
                            ? null
                            : _createStore,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: checkingInvites || selecting
                      ? null
                      : _checkInvites,
                  style: TextButton.styleFrom(
                    foregroundColor: AuthColors.green,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (checkingInvites) ...[
                        const SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Flexible(
                        child: Text(
                          checkingInvites
                              ? 'Refreshing admin access…'
                              : 'Refresh admin access',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  void _clearSearch() {
    search.clear();
    setState(() => query = '');
  }

  // Keep a failed search separate from a store list that is genuinely empty.
  Widget _noMatches() => Center(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'No stores match your search.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AuthColors.muted, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const ValueKey('clear-store-search'),
            onPressed: _clearSearch,
            style: TextButton.styleFrom(foregroundColor: AuthColors.green),
            child: const Text('Clear search'),
          ),
        ],
      ),
    ),
  );

  // Build a selectable shop row.
  Widget _storeTile(StoreInfo store, String role) => !isStoreAdminRole(role)
      ? _storeCard(store, role)
      : Dismissible(
          key: ValueKey('delete-store-${store.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: InventoryColors.error,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.white,
            ),
          ),
          confirmDismiss: (_) async {
            if (deleting != null) return false;
            final confirmed = await showProfileConfirmation(
              context: context,
              title: 'Delete ${store.name}?',
              message:
                  'This permanently removes the store, inventory, orders and conversations. Other stores and user accounts are kept.',
              action: 'Delete Store',
              cancel: 'Keep Store',
              danger: true,
            );
            if (!confirmed || !mounted) return false;
            setState(() => deleting = store.id);
            try {
              await FirestoreService.instance.deleteStore(store);
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(inventoryFeedback('Store deleted.'));
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  inventoryFeedback(
                    e is StateError
                        ? e.message
                        : 'Could not delete the store. Please try again.',
                    error: true,
                  ),
                );
              }
            } finally {
              if (mounted) setState(() => deleting = null);
            }
            return false;
          },
          child: _storeCard(store, role),
        );
  // Build the shop card and its role label.
  Widget _storeCard(StoreInfo store, String role) => Material(
    color: AuthColors.background,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AuthColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: selecting || creating || deleting != null
          ? null
          : () => _selectStore(store, role),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: AuthColors.soft,
              child: Text(
                store.name.isEmpty
                    ? 'S'
                    : store.name.characters.first.toUpperCase(),
                style: const TextStyle(
                  color: AuthColors.green,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.name,
                    style: const TextStyle(
                      color: AuthColors.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AuthColors.soft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _roleLabel(role),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AuthColors.green,
                      ),
                    ),
                  ),
                  if (store.address != null) ...[
                    const SizedBox(height: 7),
                    Text(
                      '${store.address!.city}, ${store.address!.state}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AuthColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 21),
              child: Icon(
                Icons.chevron_right_rounded,
                color: AuthColors.muted,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // Show the create-store action when no shops are available.
  Widget _emptyState() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const CircleAvatar(
        radius: 39,
        backgroundColor: AuthColors.soft,
        child: Icon(
          Icons.storefront_outlined,
          color: AuthColors.green,
          size: 38,
        ),
      ),
      const SizedBox(height: 26),
      const Text(
        'No stores yet',
        style: TextStyle(
          color: AuthColors.ink,
          fontSize: 23,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 16),
      const Text(
        'Create a store to start managing your inventory.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AuthColors.muted, fontSize: 12, height: 1.5),
      ),
      const SizedBox(height: 38),
      const Text(
        "You'll have admin access to this store.",
        style: TextStyle(color: AuthColors.muted, fontSize: 11),
      ),
    ],
  );

  // Show the store loading error and retry action.
  Widget _errorState() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.cloud_off_rounded, size: 42, color: AuthColors.muted),
      const SizedBox(height: 16),
      const Text(
        'Could not load stores',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: AuthColors.ink,
          fontSize: 20,
        ),
      ),
      const SizedBox(height: 10),
      const Text(
        'Check your connection and try again.',
        style: TextStyle(color: AuthColors.muted, fontSize: 12),
      ),
      TextButton(
        onPressed: () => setState(_streams),
        child: const Text('Retry'),
      ),
    ],
  );

  // Apply this shop role and open its home page.
  Future<void> _selectStore(StoreInfo store, String role) async {
    if (selecting) return;
    FocusScope.of(context).unfocus();
    if (widget.onSelect != null) {
      widget.onSelect!(store, role);
      return;
    }
    setState(() => selecting = true);
    try {
      await FirestoreService.instance.saveActiveStore(store.id);
      if (mounted) {
        final currentRole = storeMembershipRole(
          store.id,
          (_memberships ?? <StoreMembership>[]).map(
            (member) => (
              storeId: member.storeId,
              role: member.role,
              isActive: member.isActive,
            ),
          ),
        );
        setState(() => StoreSession.instance.select(store, role: currentRole));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open this store. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => selecting = false);
    }
  }

  // Open the new-shop form and refresh the store list.
  Future<void> _createStore() async {
    if (creating) return;
    setState(() => creating = true);
    try {
      final store = await Navigator.push<StoreInfo>(
        context,
        MaterialPageRoute(
          builder: (_) => CreateStoreDialog(onCreate: widget.onCreate),
        ),
      );
      if (store != null && mounted) {
        setState(() => StoreSession.instance.select(store, role: 'admin'));
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        final openProfile = await showStoreCreatedNotice(context);
        if (mounted && openProfile) {
          await Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
        }
      }
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  // Show Admin or Customer for this shop.
  String _roleLabel(String role) =>
      isStoreAdminRole(role) ? 'Admin' : 'Customer';
}
