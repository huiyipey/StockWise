import 'package:flutter/material.dart';

import '../models/saved_address.dart';
import '../services/address_book_service.dart';
import '../services/profile_fields.dart';
import '../theme/app_theme.dart';
import '../widgets/stockwise_ui.dart';

class EditAddressScreen extends StatefulWidget {
  final SavedAddress? address;
  final String initialName;
  final String initialPhone;
  final bool isDefault;
  final AddressBookRepository repository;
  const EditAddressScreen({
    super.key,
    this.address,
    this.initialName = '',
    this.initialPhone = '',
    this.isDefault = false,
    required this.repository,
  });

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
  bool saving = false;
  String? error;

  @override
  void dispose() {
    for (final controller in [
      label,
      name,
      phone,
      street,
      city,
      region,
      postal,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
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
        setState(() => saving = false);
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

  Widget _field(
    String key,
    String title,
    TextEditingController controller, {
    TextInputType? keyboard,
    String? Function(String?)? validator,
    int? maxLength,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: ValueKey(key),
      controller: controller,
      enabled: !saving,
      keyboardType: keyboard,
      maxLength: maxLength,
      decoration: InputDecoration(labelText: title),
      validator: validator ?? addressRequired,
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            StockWiseHeader(
              title: widget.address == null ? 'Add Address' : 'Edit Address',
              leading: saving ? null : const BackCircleButton(),
            ),
            Expanded(
              child: Form(
                key: form,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _field(
                      'address-label',
                      'Address label (Home, Work...)',
                      label,
                      maxLength: 40,
                    ),
                    _field(
                      'address-name',
                      'Recipient name',
                      name,
                      validator: profileNameError,
                      maxLength: 80,
                    ),
                    _field(
                      'address-phone',
                      'Phone number',
                      phone,
                      keyboard: TextInputType.phone,
                      validator: addressPhoneError,
                    ),
                    _field('address-street', 'Address', street, maxLength: 200),
                    _field('address-city', 'City', city, maxLength: 80),
                    _field('address-state', 'State', region, maxLength: 80),
                    _field(
                      'address-postal',
                      'Postal code',
                      postal,
                      keyboard: TextInputType.number,
                      validator: addressPostalError,
                    ),
                    const Text('Country: Malaysia'),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Default address'),
                      value: makeDefault,
                      onChanged: saving || widget.isDefault
                          ? null
                          : (value) => setState(() => makeDefault = value),
                    ),
                    if (error != null)
                      Text(
                        error!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: saving ? null : _save,
                      child: Text(saving ? 'SAVING...' : 'SAVE ADDRESS'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
