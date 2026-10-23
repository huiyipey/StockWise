import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/app_models.dart';
import '../models/barcode_product.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../screens/barcode_scanner_screen.dart';
import 'stockwise_ui.dart';

class ItemEditor extends StatefulWidget {
  final InventoryBatch? item;
  final Stream<List<StoreCategory>>? categoryStream;
  final BarcodeProductLookup? barcodeLookup;
  final Future<String?> Function()? scanBarcode;
  final InventoryItemSaver? onSave;

  const ItemEditor({
    super.key,
    this.item,
    this.categoryStream,
    this.barcodeLookup,
    this.scanBarcode,
    this.onSave,
  });

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
  late final TextEditingController quantity;
  late bool promotion;
  late bool notifications;
  DateTime? expiryAt;
  final expiryField = GlobalKey<FormFieldState<DateTime>>();
  BarcodeProduct? reusedProduct;
  List<StoreCategory> availableCategories = [];
  String? lookupMessage;
  bool lookupFailed = false;
  bool lookingUp = false;
  bool scanning = false;
  int lookupVersion = 0;
  String? category;
  XFile? image;
  bool saving = false;
  late final categoriesStream =
      widget.categoryStream ?? FirestoreService.instance.watchCategoryRecords();
  bool get busy => saving || lookingUp || scanning;
  String? get imagePath => widget.item?.imagePath ?? reusedProduct?.imagePath;

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
    quantity = TextEditingController(text: '${item?.quantityOnHand ?? 1}');
    promotion = item?.promotionEnabled ?? false;
    notifications = item?.notifyOnExpiry ?? true;
    expiryAt = item?.expiryAt;
    category = item?.categoryId;
    barcode.addListener(_barcodeChanged);
  }

  @override
  void dispose() {
    name.dispose();
    barcode.dispose();
    unit.dispose();
    basePrice.dispose();
    promotionPrice.dispose();
    quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            StockWiseHeader(
              title: widget.editing ? 'Edit Item' : 'Add New Item',
              leading: saving ? null : const BackCircleButton(),
            ),
            Expanded(
              child: StreamBuilder<List<StoreCategory>>(
                stream: categoriesStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Could not load categories. Please reopen this page.',
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final categories = snapshot.data!
                      .where((c) => c.active || c.id == widget.item?.categoryId)
                      .toList();
                  availableCategories = categories;
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
                                if (!widget.editing) ...[
                                  const Text(
                                    'Scan or enter a saved barcode to auto-fill, or fill in the details manually.',
                                  ),
                                  const SizedBox(height: 12),
                                  _barcodeField(),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: busy ? null : _lookupBarcode,
                                    icon: lookingUp
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.search_rounded),
                                    label: Text(
                                      lookingUp
                                          ? 'LOOKING UP...'
                                          : 'FIND SAVED PRODUCT',
                                    ),
                                  ),
                                  if (lookupMessage != null)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Text(
                                        lookupMessage!,
                                        style: TextStyle(
                                          color: lookupFailed
                                              ? AppColors.danger
                                              : AppColors.primaryDark,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 12),
                                ],
                                TextFormField(
                                  key: const ValueKey('item-name'),
                                  controller: name,
                                  enabled: !busy,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    labelText: 'Name',
                                  ),
                                  validator: _required,
                                ),
                                const SizedBox(height: 12),
                                FormField<DateTime>(
                                  key: expiryField,
                                  initialValue: expiryAt,
                                  validator: (value) => value == null
                                      ? 'Choose an expiry date'
                                      : null,
                                  builder: (field) => InkWell(
                                    key: const ValueKey('item-expiry'),
                                    onTap: busy ? null : _pickDate,
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: 'Expiry Date',
                                        errorText: field.errorText,
                                        prefixIcon: const Icon(
                                          Icons.calendar_month_outlined,
                                        ),
                                      ),
                                      child: Text(
                                        field.value == null
                                            ? 'Select expiry date'
                                            : DateFormat(
                                                'dd/MM/yyyy',
                                              ).format(field.value!),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _quantityRow(),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  key: ValueKey('item-category-$category'),
                                  initialValue:
                                      categories.any((c) => c.id == category)
                                      ? category
                                      : null,
                                  decoration: const InputDecoration(
                                    labelText: 'Category',
                                  ),
                                  items: categories
                                      .map(
                                        (value) => DropdownMenuItem(
                                          value: value.id,
                                          child: Text(
                                            '${value.name}${value.active ? '' : ' (archived)'}',
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: busy
                                      ? null
                                      : (value) =>
                                            setState(() => category = value),
                                  validator: (value) => value == null
                                      ? 'Choose a category'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  key: const ValueKey('item-unit'),
                                  controller: unit,
                                  enabled: !busy,
                                  decoration: const InputDecoration(
                                    labelText: 'Unit',
                                    hintText: 'unit, bottle, loaf...',
                                  ),
                                  validator: _required,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  key: const ValueKey('item-price'),
                                  controller: basePrice,
                                  enabled: !busy,
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
                                if (widget.editing) _barcodeField(),
                                SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text(
                                    'Promotion',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  value: promotion,
                                  onChanged: busy
                                      ? null
                                      : (value) =>
                                            setState(() => promotion = value),
                                ),
                                if (promotion)
                                  TextFormField(
                                    controller: promotionPrice,
                                    enabled: !busy,
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
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  value: notifications,
                                  onChanged: busy
                                      ? null
                                      : (value) => setState(
                                          () => notifications = value,
                                        ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: busy ? null : _save,
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
    ),
  );

  Widget _photoPicker() => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: busy ? null : _pickImage,
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
                  ProductArtwork(size: 72, imagePath: imagePath),
                  const SizedBox(height: 8),
                  Text(
                    imagePath == null
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

  Widget _quantityRow() => TextFormField(
    key: const ValueKey('item-quantity'),
    controller: quantity,
    enabled: !busy,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    textAlign: TextAlign.center,
    style: const TextStyle(fontWeight: FontWeight.w900),
    onChanged: (_) => setState(() {}),
    validator: (value) {
      final number = int.tryParse(value ?? '');
      return number == null || number < 0 ? 'Enter a valid quantity' : null;
    },
    decoration: InputDecoration(
      labelText: 'Quantity',
      prefixIcon: IconButton(
        tooltip: 'Decrease quantity',
        onPressed: !busy && (int.tryParse(quantity.text) ?? 0) > 0
            ? () => _changeQuantity(-1)
            : null,
        icon: const Icon(Icons.remove_circle_outline_rounded),
      ),
      suffixIcon: IconButton(
        tooltip: 'Increase quantity',
        onPressed: busy ? null : () => _changeQuantity(1),
        icon: const Icon(Icons.add_circle_outline_rounded),
      ),
    ),
  );

  void _changeQuantity(int delta) {
    final number = (int.tryParse(quantity.text) ?? 0) + delta;
    setState(() {
      quantity.value = TextEditingValue(
        text: '$number',
        selection: TextSelection.collapsed(offset: '$number'.length),
      );
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = expiryAt;
    final picked = await showDatePicker(
      context: context,
      initialDate: selected == null || selected.isBefore(today)
          ? today
          : selected,
      firstDate: today,
      lastDate: today.add(const Duration(days: 3650)),
    );
    if (picked != null && mounted) {
      setState(() => expiryAt = picked);
      expiryField.currentState?.didChange(picked);
      expiryField.currentState?.validate();
    }
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
    if (busy) return;
    setState(() => scanning = true);
    String? value;
    try {
      value =
          await (widget.scanBarcode ??
              () => Navigator.push<String>(
                context,
                MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
              ))();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not scan the barcode. You can enter it manually.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => scanning = false);
    }
    if (value != null && mounted) {
      barcode.text = value.trim();
      if (!widget.editing) await _lookupBarcode();
    }
  }

  Widget _barcodeField() => TextFormField(
    key: const ValueKey('item-barcode'),
    controller: barcode,
    enabled: !busy,
    keyboardType: TextInputType.number,
    onFieldSubmitted: widget.editing ? null : (_) => _lookupBarcode(),
    decoration: InputDecoration(
      labelText: 'Barcode',
      prefixIcon: const Icon(Icons.qr_code_scanner_rounded),
      suffixIcon: IconButton(
        tooltip: 'Scan barcode',
        onPressed: busy ? null : _scanBarcode,
        icon: const Icon(Icons.document_scanner_outlined),
      ),
    ),
  );

  void _barcodeChanged() {
    if (widget.editing) return;
    lookupVersion++;
    final hadProduct = reusedProduct != null;
    setState(() {
      reusedProduct = null;
      lookupMessage = hadProduct
          ? 'Barcode changed. Look up this code or review the details manually.'
          : null;
      lookupFailed = false;
      if (hadProduct) expiryAt = null;
    });
    if (hadProduct) expiryField.currentState?.didChange(null);
  }

  Future<void> _lookupBarcode() async {
    if (busy || widget.editing) return;
    FocusScope.of(context).unfocus();
    final code = barcode.text.trim();
    if (code.isEmpty) {
      setState(() {
        lookupMessage = 'Scan or enter a barcode first.';
        lookupFailed = true;
      });
      return;
    }
    final version = ++lookupVersion;
    setState(() {
      lookingUp = true;
      lookupMessage = null;
      lookupFailed = false;
      reusedProduct = null;
      expiryAt = null;
    });
    expiryField.currentState?.didChange(null);
    try {
      final product =
          await (widget.barcodeLookup ??
              FirestoreService.instance.findProductByBarcode)(code);
      if (!mounted || version != lookupVersion || barcode.text.trim() != code) {
        return;
      }
      if (product != null && product.barcode != code) {
        throw StateError('Barcode lookup returned a different product.');
      }
      setState(() {
        if (product == null) {
          lookupMessage = 'No saved product found. Enter the details manually.';
          return;
        }
        reusedProduct = product;
        name.text = product.name;
        unit.text = product.unitLabel;
        basePrice.text = (product.basePriceCents / 100).toStringAsFixed(2);
        category =
            availableCategories.any(
              (c) => c.id == product.categoryId && c.active,
            )
            ? product.categoryId
            : null;
        image = null;
        promotion = false;
        promotionPrice.clear();
        lookupMessage = category == null
            ? 'Product details filled. Choose a category and a new expiry date.'
            : 'Product details filled. Review them and choose a new expiry date.';
      });
    } catch (_) {
      if (mounted && version == lookupVersion) {
        setState(() {
          lookupFailed = true;
          lookupMessage =
              'Could not look up this barcode. Try again or enter the details manually.';
        });
      }
    } finally {
      if (mounted) setState(() => lookingUp = false);
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
  String? _priceValidator(String? value) {
    final amount = double.tryParse(value?.trim() ?? '');
    return amount == null || amount < 0 ? 'Enter a valid price' : null;
  }

  int _cents(String value) => (double.parse(value.trim()) * 100).round();

  Future<void> _save() async {
    if (busy || !(formKey.currentState?.validate() ?? false)) return;
    setState(() => saving = true);
    try {
      final input = InventoryItemInput(
        existing: widget.item,
        reusedProduct: reusedProduct,
        name: name.text,
        category: category!,
        unitLabel: unit.text,
        barcode: barcode.text,
        expiryAt: expiryAt!,
        quantity: int.parse(quantity.text),
        basePriceCents: _cents(basePrice.text),
        promotionEnabled: promotion,
        promotionPriceCents: promotion ? _cents(promotionPrice.text) : null,
        notifyOnExpiry: notifications,
        image: image,
      );
      await (widget.onSave ?? FirestoreService.instance.saveInventoryDraft)(
        input,
      );
      if (!mounted) return;
      setState(() => saving = false);
      await WidgetsBinding.instance.endOfFrame;
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
