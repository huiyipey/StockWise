import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/firestore_service.dart';
import '../services/store_fields.dart';
import '../services/store_session.dart';
import '../widgets/auth_ui.dart';
import '../widgets/store_ui.dart';
import 'create_store_dialog.dart';
import 'home_screen.dart';
import 'shop_screen.dart';

class StoreGateScreen extends StatefulWidget {
  const StoreGateScreen({
    super.key,
    this.storesStream,
    this.membershipsStream,
    this.accountEmail,
    this.onRefresh,
    this.onCreate,
    this.onSelect,
  });
  final Stream<List<StoreInfo>>? storesStream;
  final Stream<List<StoreMembership>>? membershipsStream;
  final String? accountEmail;
  final Future<void> Function()? onRefresh;
  final StoreCreator? onCreate;
  final void Function(StoreInfo store, String role)? onSelect;

  @override
  State<StoreGateScreen> createState() => _StoreGateScreenState();
}

class _StoreGateScreenState extends State<StoreGateScreen> {
  bool creating = false, checkingInvites = false, selecting = false;
  late Stream<List<StoreInfo>> stores;
  late Stream<List<StoreMembership>> memberships;

  @override
  void initState() {
    super.initState();
    _streams();
  }

  @override
  void didUpdateWidget(covariant StoreGateScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.storesStream != oldWidget.storesStream ||
        widget.membershipsStream != oldWidget.membershipsStream) {
      _streams();
    }
  }

  void _streams() {
    stores = widget.storesStream ?? FirestoreService.instance.watchStores();
    memberships =
        widget.membershipsStream ??
        FirestoreService.instance.watchMyMemberships();
  }

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
        ).showSnackBar(const SnackBar(content: Text('Staff access refreshed')));
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

  @override
  Widget build(BuildContext context) {
    final session = StoreSession.instance;
    if (session.store != null) {
      return session.canManage ? const HomeScreen() : const ShopScreen();
    }
    return Scaffold(
      backgroundColor: AuthColors.background,
      body: SafeArea(
        child: StreamBuilder<List<StoreInfo>>(
          stream: stores,
          builder: (context, storeSnapshot) =>
              StreamBuilder<List<StoreMembership>>(
                stream: memberships,
                builder: (context, memberSnapshot) => _content(
                  storeSnapshot.data ?? const [],
                  {
                    for (final member
                        in memberSnapshot.data ?? <StoreMembership>[])
                      member.storeId: member.role,
                  },
                  failed: storeSnapshot.hasError || memberSnapshot.hasError,
                  loading: !storeSnapshot.hasData || !memberSnapshot.hasData,
                ),
              ),
        ),
      ),
    );
  }

  Widget _content(
    List<StoreInfo> stores,
    Map<String, String> roles, {
    required bool failed,
    required bool loading,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final cardHeight = math.max(420.0 * scale, constraints.maxHeight - 260);
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 46, 20, 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                        'Choose a store',
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
                                    child: ListView.separated(
                                      padding: EdgeInsets.zero,
                                      itemCount: stores.length,
                                      separatorBuilder: (_, index) =>
                                          const SizedBox(height: 12),
                                      itemBuilder: (_, index) => _storeTile(
                                        stores[index],
                                        roles[stores[index].id] ?? 'customer',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 24),
                      StorePrimaryButton(
                        label: 'Create a store',
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
                              ? 'Refreshing staff access…'
                              : 'Refresh staff access',
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
                const SizedBox(height: 10),
                Text(
                  'Signed in as ${widget.accountEmail ?? FirebaseAuth.instance.currentUser?.email ?? ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AuthColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _storeTile(StoreInfo store, String role) => Material(
    color: AuthColors.background,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AuthColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: selecting || creating ? null : () => _selectStore(store, role),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
        "You'll be the store owner.",
        style: TextStyle(color: AuthColors.muted, fontSize: 11),
      ),
    ],
  );

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

  Future<void> _selectStore(StoreInfo store, String role) async {
    if (selecting) return;
    if (widget.onSelect != null) {
      widget.onSelect!(store, role);
      return;
    }
    setState(() => selecting = true);
    try {
      await FirestoreService.instance.saveActiveStore(store.id);
      if (mounted) {
        setState(() => StoreSession.instance.select(store, role: role));
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
        setState(() => StoreSession.instance.select(store, role: 'owner'));
      }
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  String _roleLabel(String role) => switch (role) {
    'owner' => 'Owner',
    'admin' => 'Admin',
    'manager' => 'Manager',
    'staff' => 'Staff',
    _ => 'Customer',
  };
}
