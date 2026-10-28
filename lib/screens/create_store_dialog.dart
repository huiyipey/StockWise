import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../services/store_fields.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';

class CreateStoreDialog extends StatefulWidget {
  final StoreCreator? onCreate;
  final StoreInfo? initialStore;
  const CreateStoreDialog({super.key, this.onCreate, this.initialStore});
  @override
  State<CreateStoreDialog> createState() => _CreateStoreDialogState();
}

class _CreateStoreDialogState extends State<CreateStoreDialog> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.initialStore?.name);
  late final address = TextEditingController(
    text: widget.initialStore?.shopAddress,
  );
  bool get editing => widget.initialStore != null;
  bool saving = false;
  String? error;

  @override
  void dispose() {
    name.dispose();
    address.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (saving || !(form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final store =
          await (widget.onCreate ??
              (editing
                  ? ({required String name, required String shopAddress}) =>
                        FirestoreService.instance.updateStore(
                          storeId: widget.initialStore!.id,
                          name: name,
                          shopAddress: shopAddress,
                        )
                  : FirestoreService.instance.createStore))(
            name: name.text,
            shopAddress: address.text,
          );
      if (!mounted) return;
      setState(() => saving = false);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context, store);
    } on FirebaseFunctionsException catch (failure) {
      if (mounted) {
        setState(
          () => error = switch (failure.code) {
            'already-exists' =>
              'This store name already exists. Please choose another name.',
            'invalid-argument' =>
              failure.message ?? 'Check the store name and shop address.',
            'unauthenticated' =>
              editing
                  ? 'Please sign in again to save the shop details.'
                  : 'Please sign in again to create a store.',
            'permission-denied' =>
              'Only the shop owner can edit these details.',
            'not-found' => 'This store no longer exists.',
            _ =>
              editing
                  ? 'Could not save the shop details. Please try again.'
                  : 'Could not create the store. Please try again.',
          },
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = editing
              ? 'Could not save the shop details. Please try again.'
              : 'Could not create the store. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      title: Text(editing ? 'Edit shop' : 'Create store'),
      content: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey('store-name'),
                controller: name,
                enabled: !saving,
                autofocus: true,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Store name'),
                validator: storeNameError,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('shop-address'),
                controller: address,
                enabled: !saving,
                minLines: 2,
                maxLines: 4,
                maxLength: 500,
                keyboardType: TextInputType.streetAddress,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Shop address',
                  hintText: 'Street address, city, state and postcode',
                ),
                validator: shopAddressError,
              ),
              if (error != null)
                Text(error!, style: const TextStyle(color: AppColors.danger)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : _create,
          child: Text(
            saving
                ? (editing ? 'Saving…' : 'Creating…')
                : (editing ? 'Save changes' : 'Create'),
          ),
        ),
      ],
    ),
  );
}
