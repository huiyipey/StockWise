import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/app_models.dart';
import '../models/barcode_product.dart';
import '../models/product_name.dart';
import '../services/firestore_service.dart';
import 'inventory_ui.dart';
import 'product_name_formatter.dart';
import '../screens/barcode_scanner_screen.dart';
import 'stockwise_ui.dart';

class ItemEditor extends StatefulWidget {
  final InventoryBatch? item;
  final Stream<List<StoreCategory>>? categoryStream;
  final BarcodeProductLookup? barcodeLookup;
  final Future<String?> Function()? scanBarcode;
  final InventoryItemSaver? onSave;
  final ValueChanged<String>? onSaved;

  const ItemEditor({
    super.key,
    this.item,
    this.categoryStream,
    this.barcodeLookup,
    this.scanBarcode,
    this.onSave,
    this.onSaved,
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
  final quantityField = GlobalKey<FormFieldState<String>>();
  final barcodeAnchor = GlobalKey();
  bool quantityFocused = false;
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
    name = TextEditingController(
      text: capitalizeProductName(item?.productName ?? ''),
    );
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
  Widget build(BuildContext context) => InventoryTheme(
    child: Builder(
      builder: (context) => PopScope(
        canPop: !saving,
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                InventoryHeader(
                  title: widget.editing ? 'Edit item' : 'Add item',
                  back: true,
                  onBack: saving ? null : () => Navigator.maybePop(context),
                ),
                Expanded(
                  child: StreamBuilder<List<StoreCategory>>(
                    stream: categoriesStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: InventoryEmpty(
                            title: 'Could not load categories',
                            body: 'Please reopen this page.',
                            icon: Icons.error_outline_rounded,
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final categories = snapshot.data!
                          .where(
                            (c) => c.active || c.id == widget.item?.categoryId,
                          )
                          .toList();
                      availableCategories = categories;
                      return Form(
                        key: formKey,
                        child: ListView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _photoPicker(),
                                        const SizedBox(height: 22),
                                        if (!widget.editing) ...[
                                          const Text(
                                            'Scan or enter a barcode before saving. Find a saved product or enter its details manually.',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: InventoryColors.muted,
                                              height: 1.5,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                        KeyedSubtree(
                                          key: barcodeAnchor,
                                          child: _barcodeField(),
                                        ),
                                        if (!widget.editing) ...[
                                          const SizedBox(height: 12),
                                          InventoryButton(
                                            label: lookingUp
                                                ? 'Looking up...'
                                                : 'Find saved product',
                                            icon: Icons.search_rounded,
                                            busy: lookingUp,
                                            soft: true,
                                            onPressed: busy
                                                ? null
                                                : _lookupBarcode,
                                          ),
                                          if (lookupMessage != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 14,
                                              ),
                                              child: Semantics(
                                                liveRegion: true,
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    13,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: lookupFailed
                                                        ? const Color(
                                                            0xFFFAE7E0,
                                                          )
                                                        : InventoryColors.soft,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          13,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    lookupMessage!,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      height: 1.5,
                                                      color: lookupFailed
                                                          ? InventoryColors
                                                                .error
                                                          : InventoryColors
                                                                .green,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                        const SizedBox(height: 18),
                                        TextFormField(
                                          key: const ValueKey('item-name'),
                                          controller: name,
                                          enabled: !busy,
                                          textCapitalization:
                                              TextCapitalization.words,
                                          inputFormatters: const [
                                            ProductNameFormatter(),
                                          ],
                                          style: const TextStyle(fontSize: 13),
                                          decoration: const InputDecoration(
                                            labelText: 'Name',
                                            hintText: 'e.g. Fresh Milk',
                                          ),
                                          validator: _required,
                                        ),
                                        const SizedBox(height: 18),
                                        FormField<DateTime>(
                                          key: expiryField,
                                          initialValue: expiryAt,
                                          validator: (value) => value == null
                                              ? 'Choose an expiry date'
                                              : null,
                                          builder: (field) => InkWell(
                                            key: const ValueKey('item-expiry'),
                                            onTap: busy
                                                ? null
                                                : () => _pickDate(context),
                                            child: InputDecorator(
                                              decoration: InputDecoration(
                                                labelText: 'Expiry date',
                                                errorText: field.errorText,
                                                suffixIcon: const Icon(
                                                  Icons.calendar_today_outlined,
                                                  size: 18,
                                                ),
                                              ),
                                              child: Text(
                                                field.value == null
                                                    ? 'Select expiry date'
                                                    : DateFormat(
                                                        'dd MMM yyyy',
                                                      ).format(field.value!),
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: field.value == null
                                                      ? InventoryColors.muted
                                                      : InventoryColors.ink,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                        _quantityRow(),
                                        const SizedBox(height: 18),
                                        _categoryField(categories),
                                        const SizedBox(height: 18),
                                        LayoutBuilder(
                                          builder: (context, constraints) {
                                            final fields = [
                                              TextFormField(
                                                key: const ValueKey(
                                                  'item-unit',
                                                ),
                                                controller: unit,
                                                enabled: !busy,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                ),
                                                decoration:
                                                    const InputDecoration(
                                                      labelText: 'Unit',
                                                      hintText: 'e.g. bottle',
                                                    ),
                                                validator: _required,
                                              ),
                                              TextFormField(
                                                key: const ValueKey(
                                                  'item-price',
                                                ),
                                                controller: basePrice,
                                                enabled: !busy,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                ),
                                                keyboardType:
                                                    const TextInputType.numberWithOptions(
                                                      decimal: true,
                                                    ),
                                                decoration:
                                                    const InputDecoration(
                                                      labelText:
                                                          'Regular price',
                                                      prefixText: 'RM ',
                                                      hintText: '0.00',
                                                    ),
                                                validator: _priceValidator,
                                              ),
                                            ];
                                            if (constraints.maxWidth < 275 ||
                                                MediaQuery.textScalerOf(
                                                      context,
                                                    ).scale(13) >
                                                    18) {
                                              return Column(
                                                children: [
                                                  fields[0],
                                                  const SizedBox(height: 18),
                                                  fields[1],
                                                ],
                                              );
                                            }
                                            return Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(child: fields[0]),
                                                const SizedBox(width: 16),
                                                Expanded(child: fields[1]),
                                              ],
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 14),
                                        SwitchListTile.adaptive(
                                          contentPadding: EdgeInsets.zero,
                                          title: const Text(
                                            'Promotion',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          value: promotion,
                                          onChanged: busy
                                              ? null
                                              : (value) => setState(
                                                  () => promotion = value,
                                                ),
                                        ),
                                        if (promotion) ...[
                                          const SizedBox(height: 6),
                                          TextFormField(
                                            key: const ValueKey(
                                              'item-promotion-price',
                                            ),
                                            controller: promotionPrice,
                                            enabled: !busy,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            decoration: const InputDecoration(
                                              labelText: 'Promotion price',
                                              prefixText: 'RM ',
                                              hintText: '0.00',
                                            ),
                                            validator: _priceValidator,
                                          ),
                                          const SizedBox(height: 14),
                                        ],
                                        SwitchListTile.adaptive(
                                          contentPadding: EdgeInsets.zero,
                                          title: const Text(
                                            'Receive notifications',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          subtitle: const Text(
                                            'Expiry notifications for this batch',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              color: InventoryColors.muted,
                                            ),
                                          ),
                                          value: notifications,
                                          onChanged: busy
                                              ? null
                                              : (value) => setState(
                                                  () => notifications = value,
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                InventoryButton(
                                  key: const ValueKey('save-inventory'),
                                  label: saving
                                      ? 'Saving...'
                                      : widget.editing
                                      ? 'Save changes'
                                      : 'Save item',
                                  busy: saving,
                                  onPressed: busy ? null : _save,
                                ),
                              ],
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
      ),
    ),
  );

  Widget _photoPicker() => Material(
    color: InventoryColors.background,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: InventoryColors.line),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: const ValueKey('item-photo'),
      onTap: busy ? null : _pickImage,
      child: Container(
        constraints: const BoxConstraints(minHeight: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (image != null)
              FutureBuilder<Uint8List>(
                future: image!.readAsBytes(),
                builder: (_, snapshot) => snapshot.hasData
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          snapshot.data!,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(
                        Icons.photo_outlined,
                        size: 44,
                        color: InventoryColors.green,
                      ),
              )
            else if (imagePath != null && imagePath!.isNotEmpty)
              ProductArtwork(size: 52, imagePath: imagePath)
            else
              const Icon(
                Icons.photo_outlined,
                size: 44,
                color: InventoryColors.green,
              ),
            const SizedBox(height: 12),
            Text(
              image != null || (imagePath?.isNotEmpty ?? false)
                  ? 'Replace photo'
                  : 'Choose photo',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: InventoryColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Optional / Photo library',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: InventoryColors.muted),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _quantityRow() => FormField<String>(
    key: quantityField,
    initialValue: quantity.text,
    validator: (value) {
      final number = int.tryParse(value ?? '');
      return number == null || number < 0 ? 'Enter a valid quantity' : null;
    },
    builder: (field) => Focus(
      onFocusChange: (value) => setState(() => quantityFocused = value),
      child: InputDecorator(
        isFocused: quantityFocused,
        decoration: InputDecoration(
          labelText: 'Quantity',
          enabled: !busy,
          errorText: field.errorText,
          constraints: const BoxConstraints(minHeight: 68),
          contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Decrease quantity',
              style: IconButton.styleFrom(
                foregroundColor: InventoryColors.green,
                disabledForegroundColor: InventoryColors.muted,
                minimumSize: const Size.square(40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: !busy && (int.tryParse(quantity.text) ?? 0) > 0
                  ? () => _changeQuantity(-1)
                  : null,
              icon: const Icon(Icons.remove_circle_outline_rounded),
            ),
            Expanded(
              child: TextFormField(
                key: const ValueKey('item-quantity'),
                controller: quantity,
                enabled: !busy,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
                onChanged: (value) {
                  field.didChange(value);
                  setState(() {});
                },
                decoration: const InputDecoration(
                  isCollapsed: true,
                  isDense: true,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Increase quantity',
              style: IconButton.styleFrom(
                foregroundColor: InventoryColors.green,
                minimumSize: const Size.square(40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: busy ? null : () => _changeQuantity(1),
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _categoryField(List<StoreCategory> records) {
    final choices = {
      for (final record in records)
        record.id: '${record.name}${record.active ? '' : ' (archived)'}',
    };
    return FormField<String>(
      key: ValueKey('item-category-$category'),
      initialValue: choices.containsKey(category) ? category : null,
      validator: (value) => value == null ? 'Choose a category' : null,
      builder: (field) => Semantics(
        button: true,
        child: InkWell(
          key: const ValueKey('item-category'),
          borderRadius: BorderRadius.circular(12),
          onTap: busy
              ? null
              : () async {
                  FocusScope.of(context).unfocus();
                  final value = await showInventoryCategorySheet(
                    context: context,
                    choices: choices,
                    selected: field.value ?? '',
                    title: 'Category',
                  );
                  if (value != null && mounted) {
                    field.didChange(value);
                    setState(() => category = value);
                  }
                },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Category',
              enabled: !busy,
              errorText: field.errorText,
              suffixIcon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
              ),
            ),
            child: Text(
              choices[field.value] ?? 'Select category',
              style: TextStyle(
                fontSize: 13,
                color: field.value == null
                    ? InventoryColors.muted
                    : InventoryColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _changeQuantity(int delta) {
    final number = (int.tryParse(quantity.text) ?? 0) + delta;
    setState(() {
      quantity.value = TextEditingValue(
        text: '$number',
        selection: TextSelection.collapsed(offset: '$number'.length),
      );
    });
    quantityField.currentState?.didChange(quantity.text);
  }

  Future<void> _pickDate(BuildContext pickerContext) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = expiryAt;
    final picked = await showDatePicker(
      context: pickerContext,
      initialDate: selected == null || selected.isBefore(today)
          ? today
          : selected,
      firstDate: today,
      lastDate: today.add(const Duration(days: 3650)),
      helpText: 'Choose expiry date',
      builder: (_, child) => InventoryTheme(child: child!),
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
    if (picked != null && mounted) setState(() => image = picked);
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
          inventoryFeedback(
            'Could not scan the barcode. You can enter it manually.',
            error: true,
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
    style: const TextStyle(fontSize: 13),
    autovalidateMode: AutovalidateMode.onUserInteraction,
    onFieldSubmitted: widget.editing ? null : (_) => _lookupBarcode(),
    validator: (value) => !widget.editing && (value?.trim().isEmpty ?? true)
        ? 'Scan or enter a barcode.'
        : null,
    decoration: InputDecoration(
      labelText: 'Barcode',
      hintText: 'Scan or enter barcode',
      suffixIcon: IconButton(
        tooltip: 'Scan barcode',
        onPressed: busy ? null : _scanBarcode,
        icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
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
        name.text = capitalizeProductName(product.name);
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
    if (busy) return;
    if (!(formKey.currentState?.validate() ?? false)) {
      if (!widget.editing && barcode.text.trim().isEmpty) {
        FocusScope.of(context).unfocus();
        await Scrollable.ensureVisible(
          barcodeAnchor.currentContext!,
          alignment: .2,
          duration: const Duration(milliseconds: 200),
        );
      }
      return;
    }
    setState(() => saving = true);
    try {
      final input = InventoryItemInput(
        existing: widget.item,
        reusedProduct: reusedProduct,
        name: capitalizeProductName(name.text.trim()),
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
      final message = widget.editing ? 'Item updated' : 'Item saved';
      final onSaved = widget.onSaved;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      if (onSaved != null) {
        onSaved(message);
      } else {
        messenger.showSnackBar(inventoryFeedback(message));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          inventoryFeedback(
            _friendlyError(error),
            error: true,
            action: image == null
                ? null
                : SnackBarAction(
                    label: 'Remove photo',
                    textColor: InventoryColors.error,
                    onPressed: () => setState(() => image = null),
                  ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String _friendlyError(Object error) {
    final text = '$error';
    if (text.toLowerCase().contains('storage') ||
        text.toLowerCase().contains('bucket')) {
      return 'Could not upload the photo. Try again or save without a new photo.';
    }
    if (error is ArgumentError) return '${error.message}';
    return 'Could not save the item. Please try again.';
  }
}
