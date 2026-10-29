import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_models.dart';
import '../models/store_address.dart';
import '../services/firestore_service.dart';
import '../services/postcode_lookup.dart';
import '../services/store_fields.dart';
import '../widgets/auth_ui.dart';
import '../widgets/store_ui.dart';

/// Creation opens as a page; editing uses an unbranded, scrollable dialog.
class CreateStoreDialog extends StatefulWidget {
  const CreateStoreDialog({
    super.key,
    this.onCreate,
    this.initialStore,
    this.lookupPostcode = MalaysianPostcodes.lookup,
  });
  final StoreCreator? onCreate;
  final StoreInfo? initialStore;
  final PostcodeLookup lookupPostcode;

  @override
  State<CreateStoreDialog> createState() => _CreateStoreDialogState();
}

class _CreateStoreDialogState extends State<CreateStoreDialog> {
  final form = GlobalKey<FormState>();
  final scroll = ScrollController();
  late final name = TextEditingController(text: widget.initialStore?.name);
  late final line1 = TextEditingController(
    text:
        widget.initialStore?.address?.line1 ?? widget.initialStore?.shopAddress,
  );
  late final line2 = TextEditingController(
    text: widget.initialStore?.address?.line2,
  );
  late final postcode = TextEditingController(
    text: widget.initialStore?.address?.postcode,
  );
  late final city = TextEditingController(
    text: widget.initialStore?.address?.city,
  );
  final stateName = TextEditingController();
  late final Map<TextEditingController, String> initialValues;
  Timer? debounce;
  int lookupVersion = 0;
  String? resolvedPostcode, lookupError, error;
  bool lookupFailed = false,
      lookingUp = false,
      saving = false,
      submitted = false,
      collapsed = false,
      confirmingLeave = false,
      allowExit = false;
  bool get editing => widget.initialStore != null;
  bool get hasUnsavedChanges =>
      initialValues.entries.any((entry) => entry.key.text != entry.value);

  @override
  void initState() {
    super.initState();
    // State is derived from the postcode. Its initial lookup is not a user edit.
    initialValues = {
      for (final controller in [name, line1, line2, postcode, city])
        controller: controller.text,
    };
    scroll.addListener(() {
      final next = scroll.offset > 130;
      if (next != collapsed && mounted) setState(() => collapsed = next);
    });
    if (widget.initialStore?.address != null) {
      _lookup(postcode.text, preserveCity: true);
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    lookupVersion++;
    for (final controller in [name, line1, line2, postcode, city, stateName]) {
      controller.dispose();
    }
    scroll.dispose();
    super.dispose();
  }

  void _postcodeChanged(String value) {
    debounce?.cancel();
    lookupVersion++;
    setState(() {
      resolvedPostcode = null;
      city.clear();
      stateName.clear();
      lookupError = null;
      lookupFailed = false;
      lookingUp = postcodeError(value) == null;
    });
    if (postcodeError(value) == null) {
      debounce = Timer(const Duration(milliseconds: 300), () => _lookup(value));
    }
  }

  Future<void> _lookup(String value, {bool preserveCity = false}) async {
    final version = ++lookupVersion;
    setState(() {
      lookingUp = true;
      lookupError = null;
      lookupFailed = false;
      resolvedPostcode = null;
      stateName.clear();
    });
    try {
      final location = await widget.lookupPostcode(value);
      if (!mounted || version != lookupVersion || postcode.text != value) {
        return;
      }
      setState(() {
        lookingUp = false;
        if (location == null) {
          if (!preserveCity) city.clear();
          lookupError = 'Postcode not found. Check the number.';
        } else {
          resolvedPostcode = value;
          if (!preserveCity) city.text = location.city;
          stateName.text = location.state;
        }
      });
    } catch (_) {
      if (!mounted || version != lookupVersion) return;
      setState(() {
        lookingUp = false;
        lookupFailed = true;
        lookupError = 'Could not look up this postcode.';
      });
    }
  }

  Future<void> _save() async {
    if (saving || lookingUp) return;
    setState(() => submitted = true);
    if (!(form.currentState?.validate() ?? false)) return;
    if (resolvedPostcode != postcode.text || stateName.text.isEmpty) {
      setState(
        () => lookupError = 'Enter a valid postcode to fill City and State.',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    final address = StoreAddress(
      line1: line1.text,
      line2: line2.text,
      postcode: postcode.text,
      city: city.text,
      state: stateName.text,
    );
    final validation = shopAddressError(address.formatted);
    if (validation != null) {
      setState(() => error = validation);
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final store =
          await (widget.onCreate ??
              (editing
                  ? ({required String name, required StoreAddress address}) =>
                        FirestoreService.instance.updateStore(
                          storeId: widget.initialStore!.id,
                          name: name,
                          address: address,
                        )
                  : FirestoreService.instance.createStore))(
            name: name.text,
            address: address,
          );
      if (!mounted) return;
      setState(() {
        saving = false;
        allowExit = true;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pop(context, store);
      }
    } on FirebaseFunctionsException catch (failure) {
      if (mounted) {
        setState(
          () => error = switch (failure.code) {
            'already-exists' =>
              'This store name already exists. Please choose another name.',
            'invalid-argument' =>
              failure.message ?? 'Check the store name and address.',
            'unauthenticated' =>
              'Please sign in again to save the shop details.',
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

  Future<void> _requestLeave() async {
    if (saving || confirmingLeave || allowExit) return;
    if (!hasUnsavedChanges) {
      Navigator.pop(context);
      return;
    }
    confirmingLeave = true;
    FocusScope.of(context).unfocus();
    try {
      final discard = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          title: Text(
            editing
                ? 'Discard unsaved changes?'
                : 'Leave without creating a store?',
            style: const TextStyle(
              color: AuthColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            editing
                ? 'Your shop details have unsaved changes. If you leave now, those changes will be discarded.'
                : "Your store hasn't been created. If you go back now, the information you've entered will be discarded.",
            style: const TextStyle(
              color: AuthColors.muted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                StorePrimaryButton(
                  label: 'Keep editing',
                  onPressed: () => Navigator.pop(dialogContext, false),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: TextButton.styleFrom(
                    foregroundColor: AuthColors.error,
                  ),
                  child: const Text('Discard and leave'),
                ),
              ],
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
      setState(() => allowExit = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pop(context);
      }
    } finally {
      confirmingLeave = false;
    }
  }

  Widget _fields() => Form(
    key: form,
    onChanged: () => setState(() {}),
    autovalidateMode: submitted
        ? AutovalidateMode.onUserInteraction
        : AutovalidateMode.disabled,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (editing &&
            widget.initialStore!.address == null &&
            widget.initialStore!.shopAddress.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AuthColors.soft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Previous shop address',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AuthColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.initialStore!.shopAddress,
                  style: const TextStyle(color: AuthColors.ink, fontSize: 12),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Check Address 1 and fill in the remaining fields before saving.',
                  style: TextStyle(color: AuthColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        StoreAddressField(
          fieldKey: 'store-name',
          label: 'Store name',
          controller: name,
          hint: 'e.g. Harvest Market',
          enabled: !saving,
          validator: storeNameError,
        ),
        StoreAddressField(
          fieldKey: 'address-1',
          label: 'Address 1',
          controller: line1,
          hint: 'Unit / house number and street',
          enabled: !saving,
          maxLines: 3,
          keyboardType: TextInputType.streetAddress,
          validator: addressLineError,
        ),
        StoreAddressField(
          fieldKey: 'address-2',
          label: 'Address 2',
          controller: line2,
          hint: 'Building, floor or area',
          optional: true,
          enabled: !saving,
          maxLines: 2,
          keyboardType: TextInputType.streetAddress,
          validator: (value) => addressLineError(value, required: false),
        ),
        StoreAddressField(
          fieldKey: 'postcode',
          label: 'Postcode',
          controller: postcode,
          hint: 'e.g. 47500',
          enabled: !saving,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(5),
          ],
          onChanged: _postcodeChanged,
          validator: postcodeError,
          error: lookupError,
          suffix: lookingUp
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : resolvedPostcode == postcode.text
              ? const Icon(
                  Icons.check_rounded,
                  color: AuthColors.green,
                  size: 20,
                )
              : null,
        ),
        if (lookingUp)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Finding city and state…',
              style: TextStyle(fontSize: 12, color: AuthColors.muted),
            ),
          ),
        if (lookupFailed)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _lookup(postcode.text),
              child: const Text('Retry lookup'),
            ),
          ),
        StoreAddressField(
          fieldKey: 'city',
          label: 'City',
          controller: city,
          hint: 'From postcode',
          enabled: !saving && resolvedPostcode == postcode.text,
          validator: cityError,
        ),
        StoreAddressField(
          fieldKey: 'state',
          label: 'State',
          controller: stateName,
          hint: 'From postcode',
          enabled: !saving,
          readOnly: true,
          suffix: const Icon(
            Icons.lock_outline_rounded,
            size: 18,
            color: AuthColors.muted,
          ),
        ),
        const Text(
          'State is filled from your postcode and cannot be edited.',
          style: TextStyle(
            color: AuthColors.muted,
            fontSize: 11.5,
            height: 1.4,
          ),
        ),
      ],
    ),
  );

  Widget _actions() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (error != null) ...[
        Semantics(
          liveRegion: true,
          child: Text(
            error!,
            style: const TextStyle(
              color: AuthColors.error,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
      StorePrimaryButton(
        label: saving
            ? (editing ? 'Saving…' : 'Creating…')
            : (editing ? 'Save changes' : 'Create store'),
        busy: saving,
        onPressed:
            lookingUp ||
                lookupError != null ||
                resolvedPostcode != postcode.text ||
                storeNameError(name.text) != null ||
                addressLineError(line1.text) != null ||
                addressLineError(line2.text, required: false) != null ||
                cityError(city.text) != null
            ? null
            : _save,
      ),
      TextButton(
        onPressed: saving ? null : _requestLeave,
        style: TextButton.styleFrom(foregroundColor: AuthColors.green),
        child: Text(editing ? 'Cancel' : 'Back to stores'),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving && (allowExit || !hasUnsavedChanges),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) unawaited(_requestLeave());
    },
    child: editing ? _editDialog() : _createPage(),
  );

  Widget _editDialog() => Dialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 440,
        maxHeight: MediaQuery.sizeOf(context).height * .86,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Edit shop',
                    style: TextStyle(
                      fontSize: 25,
                      color: AuthColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: saving ? null : _requestLeave,
                  tooltip: 'Close',
                  icon: const Icon(Icons.close, color: AuthColors.muted),
                ),
              ],
            ),
            const Text(
              'Update your shop name and address.',
              style: TextStyle(
                color: AuthColors.muted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: AuthColors.border, height: 1),
            Flexible(
              child: SingleChildScrollView(
                controller: scroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.only(top: 20, bottom: 20),
                child: _fields(),
              ),
            ),
            const Divider(color: AuthColors.border, height: 1),
            const SizedBox(height: 16),
            _actions(),
          ],
        ),
      ),
    ),
  );

  Widget _createPage() => Scaffold(
    backgroundColor: AuthColors.background,
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: saving ? null : _requestLeave,
                  tooltip: 'Back',
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: AuthColors.muted,
                  ),
                ),
                if (collapsed)
                  const Expanded(
                    child: Text(
                      'Create store',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: AuthColors.ink,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    children: [
                      const AuthBrand(),
                      const SizedBox(height: 36),
                      AuthCard(
                        title: 'Create store',
                        subtitle: 'Add your store name and address.',
                        children: [const SizedBox(height: 24), _fields()],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AuthColors.border)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: _actions(),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
