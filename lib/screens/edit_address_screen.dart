import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/saved_address.dart';
import '../models/store_address.dart';
import '../services/address_book_service.dart';
import '../services/customer_postcode_controller.dart';
import '../services/postcode_lookup.dart';
import '../services/profile_fields.dart';
import '../services/store_fields.dart';
import '../widgets/inventory_ui.dart';
import '../widgets/profile_ui.dart';

class EditAddressScreen extends StatefulWidget {
  const EditAddressScreen({
    super.key,
    this.address,
    this.initialName = '',
    this.initialPhone = '',
    this.isDefault = false,
    this.lookupPostcode = MalaysianPostcodes.lookup,
    required this.repository,
  });
  final SavedAddress? address;
  final String initialName, initialPhone;
  final bool isDefault;
  final AddressBookRepository repository;
  final PostcodeLookup lookupPostcode;
  @override
  State<EditAddressScreen> createState() => _EditAddressScreenState();
}

class _EditAddressScreenState extends State<EditAddressScreen> {
  final form = GlobalKey<FormState>();
  late final label = TextEditingController(text: widget.address?.label ?? '');
  late final name = TextEditingController(
    text: widget.address?.name ?? widget.initialName,
  );
  late final phone = TextEditingController(
    text: widget.address?.phone ?? widget.initialPhone,
  );
  late final street = TextEditingController(
    text: widget.address?.addressLine1 ?? '',
  );
  late final line2 = TextEditingController(
    text: widget.address?.addressLine2 ?? '',
  );
  late final city = TextEditingController(text: widget.address?.city ?? '');
  late final region = TextEditingController(text: widget.address?.state ?? '');
  late final postal = TextEditingController(
    text: widget.address?.postalCode ?? '',
  );
  late bool makeDefault = widget.isDefault;
  late final postcodeLocation = CustomerPostcodeController(
    postcode: postal,
    city: city,
    state: region,
    lookup: widget.lookupPostcode,
  );
  late final List<String> original = editableControllers
      .map((controller) => controller.text)
      .toList();
  bool saving = false, completed = false, submitted = false;
  String? error;
  List<TextEditingController> get controllers => [
    label,
    name,
    phone,
    street,
    line2,
    city,
    region,
    postal,
  ];
  List<TextEditingController> get editableControllers =>
      controllers.where((controller) => controller != region).toList();
  bool get dirty =>
      editableControllers.indexed.any(
        (entry) => entry.$2.text != original[entry.$1],
      ) ||
      makeDefault != widget.isDefault;
  @override
  void initState() {
    super.initState();
    original;
    for (final controller in controllers) {
      controller.addListener(refresh);
    }
    postcodeLocation.addListener(refresh);
    if (postal.text.isNotEmpty) unawaited(postcodeLocation.loadExisting());
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    postcodeLocation.dispose();
    for (final controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (saving || postcodeLocation.lookingUp) return;
    setState(() => submitted = true);
    if (!(form.currentState?.validate() ?? false)) return;
    if (!postcodeLocation.ready) {
      setState(() => error = 'Enter a valid postcode to fill City and State.');
      return;
    }
    final combinedError = shopAddressError(
      StoreAddress(
        line1: street.text,
        line2: line2.text,
        postcode: postal.text,
        city: city.text,
        state: region.text,
      ).formatted,
    );
    if (combinedError != null) {
      setState(() => error = combinedError);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.repository.save(
        SavedAddress(
          id: widget.address?.id ?? '',
          label: label.text,
          name: name.text,
          phone: phone.text,
          addressLine1: street.text,
          addressLine2: line2.text,
          city: city.text,
          state: region.text,
          postalCode: postal.text,
        ),
        makeDefault: makeDefault,
      );
      if (mounted) {
        setState(() {
          saving = false;
          completed = true;
        });
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not save the address. Please try again.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget field(
    String key,
    String title,
    TextEditingController controller, {
    TextInputType? keyboard,
    String? Function(String?)? validator,
    int? maxLength,
    String? hint,
    int maxLines = 1,
    bool readOnly = false,
    Widget? suffix,
    ValueChanged<String>? onChanged,
    List<TextInputFormatter>? formatters,
    bool enabled = true,
    String? inlineError,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: TextFormField(
      key: ValueKey(key),
      controller: controller,
      enabled: !saving && enabled,
      keyboardType: keyboard,
      maxLength: maxLength,
      maxLines: maxLines,
      readOnly: readOnly,
      onChanged: onChanged,
      inputFormatters: formatters,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: title,
        hintText: hint,
        counterText: '',
        suffixIcon: suffix,
        errorText: inlineError,
        errorMaxLines: 3,
      ),
      validator: validator ?? addressRequired,
    ),
  );

  @override
  Widget build(BuildContext context) => ProfileFormPage(
    title: widget.address == null ? 'Add address' : 'Edit address',
    dirty: dirty,
    busy: saving,
    completed: completed,
    discardTitle: 'Discard address changes?',
    body: Form(
      key: form,
      autovalidateMode: submitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          ProfilePanel(
            padding: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                field(
                  'address-label',
                  'Address label (Home, Work...)',
                  label,
                  maxLength: 40,
                ),
                field(
                  'address-name',
                  'Recipient name',
                  name,
                  validator: profileNameError,
                  maxLength: 80,
                ),
                field(
                  'address-phone',
                  'Phone number',
                  phone,
                  keyboard: TextInputType.phone,
                  validator: addressPhoneError,
                  hint: 'e.g. 012-345 6789',
                ),
                field(
                  'address-street',
                  'Address 1',
                  street,
                  hint: 'Unit / house number and street',
                  keyboard: TextInputType.streetAddress,
                  maxLength: 200,
                  maxLines: 3,
                  validator: addressLineError,
                ),
                field(
                  'address-line-2',
                  'Address 2 (Optional)',
                  line2,
                  hint: 'Building, floor or area',
                  keyboard: TextInputType.streetAddress,
                  maxLength: 200,
                  maxLines: 2,
                  validator: (value) =>
                      addressLineError(value, required: false),
                ),
                field(
                  'address-postal',
                  'Postcode',
                  postal,
                  keyboard: TextInputType.number,
                  validator: addressPostalError,
                  maxLength: 5,
                  hint: 'e.g. 47500',
                  formatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) {
                    error = null;
                    postcodeLocation.changed(value);
                  },
                  inlineError: postcodeLocation.error,
                ),
                if (postcodeLocation.lookingUp)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                if (postcodeLocation.lookupFailed) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: saving ? null : postcodeLocation.retry,
                      child: const Text('Retry postcode lookup'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                field(
                  'address-city',
                  'City',
                  city,
                  maxLength: 80,
                  hint: 'From postcode',
                  enabled: postcodeLocation.ready,
                  validator: cityError,
                ),
                field(
                  'address-state',
                  'State',
                  region,
                  hint: 'From postcode',
                  readOnly: true,
                  suffix: const Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: InventoryColors.muted,
                  ),
                  validator: (_) =>
                      postcodeLocation.lookingUp || postcodeLocation.ready
                      ? null
                      : 'Enter a valid postcode to fill State.',
                ),
                const Text(
                  'State is filled from your postcode and cannot be edited.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: InventoryColors.muted,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Country: Malaysia',
                  style: TextStyle(fontSize: 11, color: InventoryColors.muted),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Default address',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  value: makeDefault,
                  activeTrackColor: InventoryColors.green,
                  onChanged: saving || widget.isDefault
                      ? null
                      : (value) => setState(() => makeDefault = value),
                ),
                if (widget.isDefault)
                  const Text(
                    'This is your current default address.',
                    style: TextStyle(
                      fontSize: 11,
                      color: InventoryColors.muted,
                    ),
                  ),
                if (error != null) ...[
                  const SizedBox(height: 18),
                  ProfileNotice(error!, error: true),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
    footer: ProfileFooter(
      label: saving ? 'Saving...' : 'Save address',
      busy: saving,
      onPressed: saving || postcodeLocation.lookingUp ? null : save,
    ),
  );
}
