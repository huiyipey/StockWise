import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/firestore_service.dart';
import '../services/store_session.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'shop_screen.dart';

class StoreGateScreen extends StatefulWidget {
  const StoreGateScreen({super.key});

  @override
  State<StoreGateScreen> createState() => _StoreGateScreenState();
}

class _StoreGateScreenState extends State<StoreGateScreen> {
  bool creating = false;

  @override
  Widget build(BuildContext context) {
    final session = StoreSession.instance;
    if (session.store != null) {
      return session.canManage ? const HomeScreen() : const ShopScreen();
    }

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<StoreInfo>>(
          stream: FirestoreService.instance.watchStores(),
          builder: (context, storeSnapshot) {
            if (storeSnapshot.hasError) {
              return _ErrorState(error: storeSnapshot.error);
            }
            if (!storeSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return StreamBuilder<List<StoreMembership>>(
              stream: FirestoreService.instance.watchMyMemberships(),
              builder: (context, membershipSnapshot) {
                if (membershipSnapshot.hasError) {
                  return _ErrorState(error: membershipSnapshot.error);
                }
                final memberships =
                    membershipSnapshot.data ?? const <StoreMembership>[];
                final roleByStore = {
                  for (final item in memberships) item.storeId: item.role,
                };
                return _content(storeSnapshot.data!, roleByStore);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _content(List<StoreInfo> stores, Map<String, String> roleByStore) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
          color: AppColors.primary,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STOCKWISE',
                style: TextStyle(
                  color: Colors.white70,
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Choose a store',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Stock, carts, orders, and reports stay isolated per store.',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        Expanded(
          child: stores.isEmpty
              ? _emptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(18),
                  itemCount: stores.length,
                  itemBuilder: (context, index) {
                    final store = stores[index];
                    final role = roleByStore[store.id] ?? 'customer';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(15),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primarySoft,
                            child: Text(
                              store.name.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          title: Text(
                            store.name,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: Text(
                            '${store.code}  •  ${_roleLabel(role)}',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _selectStore(store, role),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
          child: OutlinedButton.icon(
            onPressed: creating ? null : _createStore,
            icon: const Icon(Icons.add_business_rounded),
            label: const Text('CREATE A STORE'),
          ),
        ),
      ],
    );
  }

  Widget _emptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.storefront_outlined,
            size: 68,
            color: AppColors.muted,
          ),
          const SizedBox(height: 16),
          Text(
            'No stores yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 7),
          const Text(
            'Create the first store to start managing inventory.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  Future<void> _selectStore(StoreInfo store, String role) async {
    StoreSession.instance.select(store, role: role);
    if (mounted) setState(() {});
    await FirestoreService.instance.saveActiveStore(store.id);
  }

  Future<void> _createStore() async {
    var storeName = '';
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create store'),
        content: TextField(
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Store name'),
          onChanged: (value) => storeName = value,
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, storeName),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    setState(() => creating = true);
    try {
      final store = await FirestoreService.instance.createStore(name: name);
      StoreSession.instance.select(store, role: 'owner');
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  String _roleLabel(String role) => switch (role) {
    'owner' => 'Owner',
<<<<<<< HEAD
    'admin' => 'Admin',
=======
<<<<<<< HEAD
    'admin' => 'Admin',
=======
>>>>>>> 831768e476072760b30a26d67dfa6f0d1864723f
>>>>>>> c329d3aa1357b4e87b680ad91ce3b6d980a28249
    'manager' => 'Manager',
    'staff' => 'Staff',
    _ => 'Customer',
  };
}

class _ErrorState extends StatelessWidget {
  final Object? error;

  const _ErrorState({this.error});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 54,
            color: AppColors.danger,
          ),
          const SizedBox(height: 12),
          const Text(
            'Could not load stores',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text('$error', textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
