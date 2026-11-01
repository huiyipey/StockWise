import 'package:flutter/material.dart';

import '../models/saved_address.dart';
import '../services/address_book_service.dart';
import '../widgets/inventory_ui.dart';
import '../widgets/profile_ui.dart';
import '../widgets/profile_tag.dart';
import 'edit_address_screen.dart';

class AddressBookScreen extends StatefulWidget {
  const AddressBookScreen({
    super.key,
    this.initialName = '',
    this.initialPhone = '',
    this.repository,
  });
  final String initialName, initialPhone;
  final AddressBookRepository? repository;
  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> {
  late final repository = widget.repository ?? AddressBookService.instance;
  late final book = repository.watch();
  bool busy = false;
  String? operationMessage, error;

  Future<void> edit(AddressBook data, [SavedAddress? address]) async {
    final saved = await Navigator.push<bool>(
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
    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(inventoryFeedback('Address saved'));
    }
  }

  Future<void> operation(
    Future<void> Function() action,
    String message, {
    String? success,
  }) async {
    if (busy) return;
    setState(() {
      busy = true;
      operationMessage = message;
      error = null;
    });
    try {
      await action();
      if (mounted && success != null) {
        ScaffoldMessenger.of(context).showSnackBar(inventoryFeedback(success));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not update the address book. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          operationMessage = null;
        });
      }
    }
  }

  Future<void> delete(SavedAddress address) async {
    if (await showProfileConfirmation(
          context: context,
          title: 'Delete address?',
          message: 'Remove ${address.label} from your address book?',
          action: 'Delete',
          cancel: 'Cancel',
          danger: true,
        ) &&
        mounted) {
      await operation(
        () => repository.delete(address.id),
        'Deleting address...',
        success: 'Address deleted',
      );
    }
  }

  @override
  Widget build(BuildContext context) => InventoryTheme(
    child: Builder(
      builder: (context) => PopScope(
        canPop: !busy,
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                InventoryHeader(
                  title: 'Address book',
                  back: true,
                  onBack: busy ? null : () => Navigator.maybePop(context),
                ),
                Expanded(
                  child: StreamBuilder<AddressBook>(
                    stream: book,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const SingleChildScrollView(
                          child: ProfileEmpty(
                            'Could not load addresses',
                            body: 'Please reopen this page.',
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }
                      final data = snapshot.data!;
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        children: [
                          const Text(
                            'Your default address fills delivery details at checkout. Your first saved address becomes the default.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: InventoryColors.muted,
                            ),
                          ),
                          const SizedBox(height: 22),
                          InventoryButton(
                            label: 'Add address',
                            icon: Icons.add_rounded,
                            onPressed: busy ? null : () => edit(data),
                          ),
                          const SizedBox(height: 20),
                          if (data.addresses.isEmpty)
                            const ProfileEmpty(
                              'No saved addresses yet',
                              body: 'Add your first delivery address.',
                              icon: Icons.location_on_outlined,
                            ),
                          for (final address in data.addresses)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: ProfilePanel(
                                key: ValueKey('saved-${address.id}'),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on_outlined,
                                          color: InventoryColors.green,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            address.label,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        if (data.defaultAddress?.id ==
                                            address.id)
                                          const ProfileTag('Default'),
                                      ],
                                    ),
                                    const SizedBox(height: 18),
                                    Text(
                                      address.name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      address.phone,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: InventoryColors.muted,
                                      ),
                                    ),
                                    const SizedBox(height: 9),
                                    Text(
                                      address.formatted,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        height: 1.6,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      alignment: WrapAlignment.end,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 8,
                                      children: [
                                        if (data.defaultAddress?.id !=
                                            address.id)
                                          TextButton(
                                            onPressed: busy
                                                ? null
                                                : () => operation(
                                                    () => repository.setDefault(
                                                      address.id,
                                                    ),
                                                    'Updating your default address...',
                                                  ),
                                            child: const Text(
                                              'Set as default',
                                              style: TextStyle(fontSize: 11),
                                            ),
                                          ),
                                        TextButton.icon(
                                          onPressed: busy
                                              ? null
                                              : () => edit(data, address),
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            'Edit',
                                            style: TextStyle(fontSize: 11),
                                          ),
                                        ),
                                        TextButton.icon(
                                          onPressed: busy
                                              ? null
                                              : () => delete(address),
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            'Delete',
                                            style: TextStyle(fontSize: 11),
                                          ),
                                          style: TextButton.styleFrom(
                                            foregroundColor:
                                                InventoryColors.error,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (operationMessage != null)
                            ProfileNotice(operationMessage!, busy: true),
                          if (error != null) ProfileNotice(error!, error: true),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
