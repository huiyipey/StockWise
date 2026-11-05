import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/postcode_lookup.dart';
import '../widgets/inventory_ui.dart';
import '../widgets/profile_ui.dart';

class DeliveryFeeScreen extends StatefulWidget {
  const DeliveryFeeScreen({super.key, this.loader, this.onSave});
  final Future<Map<String, dynamic>> Function()? loader;
  final Future<void> Function(Map<String, dynamic>)? onSave;
  @override
  State<DeliveryFeeScreen> createState() => _DeliveryFeeScreenState();
}

class _DeliveryFeeScreenState extends State<DeliveryFeeScreen> {
  final form = GlobalKey<FormState>();
  final fixed = TextEditingController(text: '5.00');
  final rows =
      <({TextEditingController postcode, TextEditingController amount})>[];
  String mode = 'fixed', initial = '', error = '';
  bool loading = true, saving = false, complete = false;
  Map<String, dynamic> get raw => {
    'mode': mode,
    'fixed': fixed.text,
    'rows': rows.map((r) => '${r.postcode.text}:${r.amount.text}').join('|'),
  };
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data =
          await (widget.loader ??
              () => FirestoreService.instance.watchCommerceSettings().first)();
      if (!mounted) return;
      setState(() {
        mode = data['deliveryFeeMode'] as String? ?? 'fixed';
        fixed.text = ((data['deliveryFeeCents'] as num? ?? 500) / 100)
            .toStringAsFixed(2);
        for (final entry in (data['postcodeFees'] as Map? ?? {}).entries) {
          rows.add((
            postcode: TextEditingController(text: '${entry.key}'),
            amount: TextEditingController(
              text: ((entry.value as num) / 100).toStringAsFixed(2),
            ),
          ));
        }
        loading = false;
        initial = raw.toString();
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Could not load delivery fees. Please reopen this page.';
        });
      }
    }
  }

  @override
  void dispose() {
    fixed.dispose();
    for (final r in rows) {
      r.postcode.dispose();
      r.amount.dispose();
    }
    super.dispose();
  }

  String? money(String? text) {
    final value = double.tryParse(text ?? '');
    return value == null || !value.isFinite || value < 0
        ? 'Enter a valid delivery fee.'
        : null;
  }

  Future<void> save() async {
    if (saving || !(form.currentState?.validate() ?? false)) return;
    setState(() {
      saving = true;
      error = '';
    });
    try {
      final fees = <String, int>{};
      if (mode == 'postcode') {
        for (final row in rows) {
          final postcode = row.postcode.text.trim();
          if (fees.containsKey(postcode)) {
            throw StateError('Each postcode can appear only once.');
          }
          if (await MalaysianPostcodes.lookup(postcode) == null) {
            throw StateError('Postcode $postcode was not found.');
          }
          fees[postcode] = (double.parse(row.amount.text) * 100).round();
        }
      }
      final config = {
        'mode': mode,
        'fixedCents': (double.parse(fixed.text) * 100).round(),
        'postcodeFees': fees,
      };
      if (widget.onSave != null) {
        await widget.onSave!(config);
      } else {
        await FirestoreService.instance.saveDeliveryFees(
          mode: mode,
          fixedCents: config['fixedCents'] as int,
          postcodeFees: fees,
        );
      }
      if (!mounted) return;
      setState(() {
        complete = true;
        saving = false;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is StateError
              ? e.message
              : 'Could not save delivery fees. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ProfileFormPage(
    title: 'Manage Delivery Fee',
    busy: saving,
    completed: complete,
    dirty: initial.isNotEmpty && initial != raw.toString(),
    footer: ProfileFooter(
      label: 'Save Changes',
      busy: saving,
      onPressed: loading || error.startsWith('Could not load') ? null : save,
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Form(
              key: form,
              onChanged: () => setState(() {}),
              child: ProfilePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InventoryChoiceField(
                      key: const ValueKey('delivery-fee-type'),
                      label: 'Delivery Fee Type',
                      value: mode,
                      enabled: !saving,
                      choices: const {
                        'fixed': 'Fixed Amount',
                        'postcode': 'By Malaysian Postcode',
                      },
                      onChanged: (value) => setState(() => mode = value),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: fixed,
                      enabled: !saving,
                      style: const TextStyle(
                        fontSize: 14,
                        color: InventoryColors.muted,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: money,
                      decoration: inventoryEditorDecoration(
                        mode == 'fixed'
                            ? 'Delivery Fee per Order'
                            : 'Fixed Fee (Used in Fixed Amount Mode)',
                        prefixText: 'RM ',
                        hintText: '0.00',
                      ),
                    ),
                    if (mode == 'postcode') ...[
                      const SizedBox(height: 18),
                      const Text(
                        'Customers cannot place orders to a postcode until its delivery fee is saved here.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: InventoryColors.muted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (int i = 0; i < rows.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: rows[i].postcode,
                                  enabled: !saving,
                                  keyboardType: TextInputType.number,
                                  maxLength: 5,
                                  decoration: const InputDecoration(
                                    labelText: 'Postcode',
                                    counterText: '',
                                  ),
                                  validator: (v) =>
                                      RegExp(r'^\d{5}$').hasMatch(v ?? '')
                                      ? null
                                      : 'Use 5 digits.',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: rows[i].amount,
                                  enabled: !saving,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Delivery Fee',
                                    prefixText: 'RM ',
                                  ),
                                  validator: money,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remove postcode',
                                onPressed: saving
                                    ? null
                                    : () => setState(() {
                                        final row = rows.removeAt(i);
                                        FocusScope.of(context).unfocus();
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                              row.postcode.dispose();
                                              row.amount.dispose();
                                            });
                                      }),
                                icon: const Icon(
                                  Icons.remove_circle_outline_rounded,
                                  color: InventoryColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      InventoryButton(
                        label: 'Add Postcode',
                        icon: Icons.add_rounded,
                        soft: true,
                        onPressed: saving
                            ? null
                            : () => setState(
                                () => rows.add((
                                  postcode: TextEditingController(),
                                  amount: TextEditingController(),
                                )),
                              ),
                      ),
                    ],
                    if (error.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ProfileNotice(error, error: true),
                    ],
                  ],
                ),
              ),
            ),
          ),
  );
}
