import 'package:flutter/material.dart';
import '../models/saved_address.dart';
import '../services/address_book_service.dart';
import '../services/profile_fields.dart';
import '../widgets/inventory_ui.dart';
import '../widgets/profile_ui.dart';

class EditAddressScreen extends StatefulWidget {
  const EditAddressScreen({
    super.key,
    this.address,
    this.initialName = '',
    this.initialPhone = '',
    this.isDefault = false,
    required this.repository,
  });
  final SavedAddress? address;
  final String initialName, initialPhone;
  final bool isDefault;
  final AddressBookRepository repository;
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
  late final city = TextEditingController(text: widget.address?.city ?? '');
  late final region = TextEditingController(text: widget.address?.state ?? '');
  late final postal = TextEditingController(
    text: widget.address?.postalCode ?? '',
  );
  late bool makeDefault = widget.isDefault;
  late final List<String> original = controllers
      .map((controller) => controller.text)
      .toList();
  bool saving = false, completed = false;
  String? error;
  List<TextEditingController> get controllers => [
    label,
    name,
    phone,
    street,
    city,
    region,
    postal,
  ];
  bool get dirty =>
      controllers.indexed.any((entry) => entry.$2.text != original[entry.$1]) ||
      makeDefault != widget.isDefault;
  @override
  void initState() {
    super.initState();
    original;
    for (final controller in controllers) {
      controller.addListener(refresh);
    }
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (saving || !(form.currentState?.validate() ?? false)) return;
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
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: TextFormField(
      key: ValueKey(key),
      controller: controller,
      enabled: !saving,
      keyboardType: keyboard,
      maxLength: maxLength,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(labelText: title, counterText: ''),
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
                ),
                field('address-street', 'Address', street, maxLength: 200),
                field('address-city', 'City', city, maxLength: 80),
                field('address-state', 'State', region, maxLength: 80),
                field(
                  'address-postal',
                  'Postal code',
                  postal,
                  keyboard: TextInputType.number,
                  validator: addressPostalError,
                ),
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
      onPressed: saving ? null : save,
    ),
  );
}
