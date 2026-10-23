import 'package:flutter/material.dart';

import '../models/saved_address.dart';
import '../services/address_book_service.dart';
import '../theme/app_theme.dart';
import '../widgets/stockwise_ui.dart';
import 'edit_address_screen.dart';

class AddressBookScreen extends StatefulWidget {
  final String initialName;
  final String initialPhone;
  final AddressBookRepository? repository;
  const AddressBookScreen({
    super.key,
    this.initialName = '',
    this.initialPhone = '',
    this.repository,
  });
  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> {
  late final repository = widget.repository ?? AddressBookService.instance;
  late final book = repository.watch();
  bool busy = false;

  Future<void> _edit(AddressBook data, [SavedAddress? address]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditAddressScreen(
          address: address,
          initialName: widget.initialName,
          initialPhone: widget.initialPhone,
          isDefault: address != null && data.defaultAddress?.id == address.id,
          repository: repository,
        ),
      ),
    );
  }

  Future<void> _operation(Future<void> Function() operation) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await operation();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not update the address book. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _delete(SavedAddress address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete address?'),
        content: Text('Remove ${address.label} from your address book?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _operation(() => repository.delete(address.id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const StockWiseHeader(
            title: 'Address Book',
            leading: BackCircleButton(),
          ),
          Expanded(
            child: StreamBuilder<AddressBook>(
              stream: book,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Could not load your addresses. Please reopen this page.',
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data!;
                return ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    const Text(
                      'Your default address fills delivery details at checkout. Your first saved address becomes the default.',
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: busy ? null : () => _edit(data),
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: const Text('ADD ADDRESS'),
                    ),
                    const SizedBox(height: 18),
                    if (data.addresses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'No saved addresses yet. Add your first delivery address.',
                        ),
                      ),
                    ...data.addresses.map((address) {
                      final isDefault = data.defaultAddress?.id == address.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          key: ValueKey('saved-${address.id}'),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        address.label,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    if (isDefault) const StatusPill('Default'),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('${address.name}  •  ${address.phone}'),
                                Text(address.formatted),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    if (!isDefault)
                                      TextButton(
                                        onPressed: busy
                                            ? null
                                            : () => _operation(
                                                () => repository.setDefault(
                                                  address.id,
                                                ),
                                              ),
                                        child: const Text('Set as default'),
                                      ),
                                    TextButton.icon(
                                      onPressed: busy
                                          ? null
                                          : () => _edit(data, address),
                                      icon: const Icon(Icons.edit_outlined),
                                      label: const Text('Edit'),
                                    ),
                                    TextButton.icon(
                                      onPressed: busy
                                          ? null
                                          : () => _delete(address),
                                      icon: const Icon(Icons.delete_outline),
                                      label: const Text('Delete'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.danger,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
