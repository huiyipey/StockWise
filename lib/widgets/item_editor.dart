import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/app_models.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../screens/barcode_scanner_screen.dart';
import 'stockwise_ui.dart';

class ItemEditor extends StatefulWidget {
  final InventoryBatch? item;

  const ItemEditor({super.key, this.item});

  bool get editing => item != null;

  @override
  State<ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<ItemEditor> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController barcode;
  late final TextEditingController unit;
  late final TextEditingController basePrice;
  late final TextEditingController promotionPrice;
  late int quantity;
  late bool promotion;
  late bool notifications;
  late DateTime expiryAt;
  String? category;
  XFile? image;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    name = TextEditingController(text: item?.productName ?? '');
    barcode = TextEditingController(text: item?.barcode ?? '');
    unit = TextEditingController(text: item?.unitLabel ?? 'unit');
    basePrice = TextEditingController(
      text: item == null ? '' : (item.basePriceCents / 100).toStringAsFixed(2),
    );
    promotionPrice = TextEditingController(
      text: item?.promotionPriceCents == null
          ? ''
          : (item!.promotionPriceCents! / 100).toStringAsFixed(2),
    );
    quantity = item?.quantityOnHand ?? 1;
    promotion = item?.promotionEnabled ?? false;
    notifications = item?.notifyOnExpiry ?? true;
    expiryAt = item?.expiryAt ?? DateTime.now().add(const Duration(days: 7));
    category = item?.categoryId;
  }

  @override
  void dispose() {
    name.dispose();
    barcode.dispose();
    unit.dispose();
    basePrice.dispose();
    promotionPrice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          StockWiseHeader(
            title: widget.editing ? 'Edit Item' : 'Add New Item',
            leading: const BackCircleButton(),
          ),
          Expanded(
            child: StreamBuilder<List<String>>(
              stream: FirestoreService.instance.watchCategories(),
              builder: (context, snapshot) {
                final categories = snapshot.data ?? const <String>[];
                final matching = categories.where(
                  (value) =>
                      category != null && _slug(value) == _slug(category!),
                );
                if (matching.isNotEmpty) category = matching.first;
                return Form(
                  key: formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 34),
                    children: [
                      _photoPicker(),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              TextFormField(
                                controller: name,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'Name',
                                ),
                                validator: _required,
                              ),
                              const SizedBox(height: 12),
                              InkWell(
                                onTap: _pickDate,
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Expiry Date',
                                    prefixIcon: Icon(
                                      Icons.calendar_month_outlined,
                                    ),
                                  ),
                                  child: Text(
                                    DateFormat('dd/MM/yyyy').format(expiryAt),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _quantityRow(),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: categories.contains(category)
                                    ? category
                                    : null,
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                ),
                                items: categories
                                    .map(
                                      (value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(value),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) =>
                                    setState(() => category = value),
                                validator: (value) =>
                                    value == null ? 'Choose a category' : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: unit,
                                decoration: const InputDecoration(
                                  labelText: 'Unit',
                                  hintText: 'unit, bottle, loaf...',
                                ),
                                validator: _required,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: basePrice,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Regular Price',
                                  prefixText: 'RM  ',
                                ),
                                validator: _priceValidator,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: barcode,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Barcode',
                                  prefixIcon: const Icon(
                                    Icons.qr_code_scanner_rounded,
                                  ),
                                  suffixIcon: IconButton(
                                    tooltip: 'Scan barcode',
                                    onPressed: _scanBarcode,
                                    icon: const Icon(
                                      Icons.document_scanner_outlined,
                                    ),
                                  ),
                                ),
                              ),
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Promotion',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                value: promotion,
                                onChanged: (value) =>
                                    setState(() => promotion = value),
                              ),
                              if (promotion)
                                TextFormField(
                                  controller: promotionPrice,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Promotion Price',
                                    prefixText: 'RM  ',
                                  ),
                                  validator: _priceValidator,
                                ),
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Receive Notifications',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                value: notifications,
                                onChanged: (value) =>
                                    setState(() => notifications = value),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: saving ? null : _save,
                                child: Text(
                                  saving
                                      ? 'SAVING...'
                                      : widget.editing
                                      ? 'SAVE CHANGES'
                                      : 'SAVE ITEM',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

  Widget _photoPicker() => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: _pickImage,
      child: Container(
        height: 150,
        alignment: Alignment.center,
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F2EF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: image == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ProductArtwork(size: 72, imagePath: widget.item?.imagePath),
                  const SizedBox(height: 8),
                  Text(
                    widget.item?.imagePath == null
                        ? 'Choose Photo (optional)'
                        : 'Replace Photo',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primaryDark,
                    size: 42,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    image!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
      ),
    ),
  );

  Widget _quantityRow() => InputDecorator(
    decoration: const InputDecoration(labelText: 'Quantity'),
    child: Row(
      children: [
        IconButton(
          onPressed: quantity > 0 ? () => setState(() => quantity--) : null,
          icon: const Icon(Icons.remove_circle_outline_rounded),
        ),
        Expanded(
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        IconButton(
          onPressed: () => setState(() => quantity++),
          icon: const Icon(Icons.add_circle_outline_rounded),
        ),
      ],
    ),
  );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: expiryAt.isBefore(DateTime.now())
          ? DateTime.now()
          : expiryAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => expiryAt = picked);
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (picked != null) setState(() => image = picked);
  }

  Future<void> _scanBarcode() async {
    final value = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (value != null && mounted) {
      setState(() => barcode.text = value);
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
  String? _priceValidator(String? value) {
    final amount = double.tryParse(value?.trim() ?? '');
    return amount == null || amount < 0 ? 'Enter a valid price' : null;
  }

  int _cents(String value) => (double.parse(value.trim()) * 100).round();
  String _slug(String value) => value.toLowerCase().replaceAll(' ', '-');

  Future<void> _save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() => saving = true);
    try {
      await FirestoreService.instance.saveInventoryItem(
        existing: widget.item,
        name: name.text,
        category: category!,
        unitLabel: unit.text,
        barcode: barcode.text,
        expiryAt: expiryAt,
        quantity: quantity,
        basePriceCents: _cents(basePrice.text),
        promotionEnabled: promotion,
        promotionPriceCents: promotion ? _cents(promotionPrice.text) : null,
        notifyOnExpiry: notifications,
        image: image,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.editing ? 'Item updated' : 'Item saved')),
      );
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String _friendlyError(Object error) {
    final text = '$error';
    if (text.toLowerCase().contains('storage') ||
        text.toLowerCase().contains('bucket')) {
      return 'Photo upload needs Firebase Storage billing. Save without a new photo for now.';
    }
    return text.replaceFirst('Invalid argument(s): ', '');
  }
}
