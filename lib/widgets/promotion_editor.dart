import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../models/promotion.dart';
import '../services/firestore_service.dart';
import '../screens/barcode_scanner_screen.dart';
import 'inventory_ui.dart';

class PromotionEditor extends StatefulWidget {
  const PromotionEditor({
    super.key,
    required this.initial,
    required this.basePriceCents,
    required this.onChanged,
    this.enabled = true,
    this.products,
  });
  final Map<String, dynamic> initial;
  final int basePriceCents;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final bool enabled;
  final Stream<List<InventoryBatch>>? products;
  @override
  State<PromotionEditor> createState() => _PromotionEditorState();
}

class _PromotionEditorState extends State<PromotionEditor> {
  late String type = widget.initial['type'] as String? ?? 'percentage';
  late String requirement =
      widget.initial['requirement'] as String? ?? 'quantity';
  late String reward = widget.initial['reward'] as String? ?? 'free';
  late String targetId = widget.initial['targetProductId'] as String? ?? '',
      targetName = widget.initial['targetProductName'] as String? ?? '';
  late final discount = TextEditingController(
    text: type == 'percentage'
        ? _number(widget.initial['percentage'])
        : _money(widget.initial['amountCents']),
  );
  late final threshold = TextEditingController(
    text: requirement == 'quantity'
        ? _number(widget.initial['thresholdQuantity'])
        : _money(widget.initial['thresholdSpendCents']),
  );
  late final gifts = TextEditingController(
    text: '${widget.initial['giftQuantity'] ?? 1}',
  );
  late final rewardValue = TextEditingController(
    text: reward == 'percentage'
        ? _number(widget.initial['rewardPercentage'])
        : _money(widget.initial['rewardAmountCents']),
  );
  String _number(dynamic value) => value == null ? '' : '$value';
  String _money(dynamic value) =>
      value is num ? (value / 100).toStringAsFixed(2) : '';
  int _cents(String value) {
    final number = double.tryParse(value);
    return number == null || !number.isFinite ? 0 : (number * 100).round();
  }

  Map<String, dynamic> get data {
    final result = <String, dynamic>{
      'type': type,
      if (type == 'percentage')
        'percentage': double.tryParse(discount.text) ?? 0,
      if (type == 'fixed') 'amountCents': _cents(discount.text),
      if (type == 'bundle') ...{
        'requirement': requirement,
        'thresholdQuantity': int.tryParse(threshold.text) ?? 0,
        'thresholdSpendCents': _cents(threshold.text),
        'targetProductId': targetId,
        'targetProductName': targetName,
        'giftQuantity': int.tryParse(gifts.text) ?? 0,
        'reward': reward,
        'rewardPercentage': double.tryParse(rewardValue.text) ?? 0,
        'rewardAmountCents': _cents(rewardValue.text),
      },
    };
    if (type == 'bundle') result['label'] = Promotion(result).label;
    return result;
  }

  void changed() => widget.onChanged(data);
  @override
  void dispose() {
    discount.dispose();
    threshold.dispose();
    gifts.dispose();
    rewardValue.dispose();
    super.dispose();
  }

  Widget select(
    String label,
    String value,
    Map<String, String> values,
    ValueChanged<String> change,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: InventoryChoiceField(
      key: ValueKey('promotion-$label-$value'),
      label: label,
      value: value,
      choices: values,
      enabled: widget.enabled,
      onChanged: (v) => setState(() {
        change(v);
        changed();
      }),
    ),
  );
  Widget field(
    String key,
    String label,
    TextEditingController controller, {
    bool money = false,
    bool percent = false,
    int? maximum,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: ValueKey(key),
      controller: controller,
      enabled: widget.enabled,
      style: const TextStyle(fontSize: 14, color: InventoryColors.muted),
      keyboardType: TextInputType.numberWithOptions(decimal: money || percent),
      decoration: inventoryEditorDecoration(
        label,
        prefixText: money ? 'RM ' : null,
        suffixText: percent ? '%' : null,
        hintText: money
            ? '0.00'
            : percent
            ? 'e.g. 10'
            : 'e.g. 2',
      ),
      onChanged: (_) => changed(),
      validator: (value) {
        final n = double.tryParse(value ?? '');
        if (n == null ||
            !n.isFinite ||
            n <= 0 ||
            (money && _cents(value ?? '') <= 0) ||
            (!money && !percent && int.tryParse(value ?? '') == null)) {
          return 'Enter a valid positive value.';
        }
        if (percent && n >= 100) return 'Use a percentage below 100.';
        if (maximum != null && (money ? _cents(value!) : n) >= maximum) {
          return 'Discount must be below the regular price.';
        }
        return null;
      },
    ),
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      select(
        'Promotion Type',
        type,
        const {
          'percentage': 'Percentage',
          'fixed': 'Fixed Amount',
          'bundle': 'Buy X Get Y',
        },
        (v) {
          type = v;
          discount.clear();
        },
      ),
      if (type != 'bundle')
        field(
          'item-promotion-discount',
          type == 'percentage' ? 'Discount Percentage' : 'Discount Amount',
          discount,
          money: type == 'fixed',
          percent: type == 'percentage',
          maximum: type == 'fixed' ? widget.basePriceCents : null,
        ),
      if (type == 'bundle') ...[
        select(
          'Purchase Requirement',
          requirement,
          const {
            'quantity': 'Buy a quantity of this product',
            'spend': 'Spend an amount on this product',
          },
          (v) {
            requirement = v;
            threshold.clear();
          },
        ),
        field(
          'promotion-threshold',
          requirement == 'quantity'
              ? 'Quantity to Buy'
              : 'Minimum Product Spend',
          threshold,
          money: requirement == 'spend',
        ),
        FormField<String>(
          initialValue: targetId,
          validator: (_) =>
              targetId.isEmpty ? 'Choose the bundle product.' : null,
          builder: (state) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: InkWell(
              onTap: !widget.enabled
                  ? null
                  : () async {
                      final item = await chooseBundleProduct(
                        context,
                        products: widget.products,
                      );
                      if (item == null || !mounted) return;
                      setState(() {
                        targetId = item.productId;
                        targetName = item.productName;
                        state.didChange(targetId);
                        changed();
                      });
                    },
              child: InputDecorator(
                decoration: inventoryEditorDecoration(
                  'Bundle Product (Y)',
                  errorText: state.errorText,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        targetName.isEmpty
                            ? 'Search name or barcode'
                            : targetName,
                        style: const TextStyle(
                          fontSize: 14,
                          color: InventoryColors.muted,
                        ),
                      ),
                    ),
                    const Icon(Icons.search_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
        select(
          'Bundle Discount',
          reward,
          const {
            'free': 'Get It Free',
            'percentage': 'Discount Percentage',
            'fixed': 'Fixed Discount Amount',
          },
          (v) {
            reward = v;
            rewardValue.clear();
          },
        ),
        field('promotion-gift-quantity', 'Bundle Quantity', gifts),
        if (reward != 'free')
          field(
            'promotion-reward',
            reward == 'percentage'
                ? 'Bundle Discount Percentage'
                : 'Bundle Discount Amount',
            rewardValue,
            money: reward == 'fixed',
            percent: reward == 'percentage',
          ),
      ],
    ],
  );
}

Future<InventoryBatch?> chooseBundleProduct(
  BuildContext context, {
  Stream<List<InventoryBatch>>? products,
}) => showModalBottomSheet<InventoryBatch>(
  context: context,
  isScrollControlled: true,
  backgroundColor: InventoryColors.background,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (_) => _BundleProductSheet(products: products),
);

class _BundleProductSheet extends StatefulWidget {
  const _BundleProductSheet({this.products});
  final Stream<List<InventoryBatch>>? products;
  @override
  State<_BundleProductSheet> createState() => _BundleProductSheetState();
}

class _BundleProductSheetState extends State<_BundleProductSheet> {
  final query = TextEditingController();
  late final source =
      widget.products ?? FirestoreService.instance.watchInventory();
  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => InventoryTheme(
    child: SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .8,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choose Bundle Product',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: query,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search name or barcode',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    tooltip: 'Scan bundle barcode',
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    onPressed: () async {
                      final value = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BarcodeScannerScreen(),
                        ),
                      );
                      if (value != null && mounted) {
                        setState(() => query.text = value);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<List<InventoryBatch>>(
                  stream: source,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const InventoryEmpty(
                        title: 'Could not load products',
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final needle = query.text.trim().toLowerCase(),
                        seen = <String>{};
                    final rows = snapshot.data!
                        .where(
                          (b) =>
                              b.canSellAt(DateTime.now()) &&
                              (b.productName.toLowerCase().contains(needle) ||
                                  (b.barcode ?? '').toLowerCase().contains(
                                    needle,
                                  )) &&
                              seen.add(b.productId),
                        )
                        .toList();
                    if (rows.isEmpty) {
                      return const InventoryEmpty(
                        title: 'No matching products',
                      );
                    }
                    return ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        final item = rows[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            title: Text(item.productName),
                            subtitle: Text(
                              '${item.barcode ?? "No barcode"} / RM ${(item.sellingPriceCents / 100).toStringAsFixed(2)}',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => Navigator.pop(context, item),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
