import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_models.dart';
import '../models/barcode_product.dart';
import '../models/category_label.dart';
import '../models/product_name.dart';
import '../services/firestore_service.dart';
import '../services/image_upload.dart';
import '../services/inventory_catalogue_service.dart';
import '../services/store_session.dart';
import '../widgets/inventory_ui.dart';
import '../widgets/product_name_formatter.dart';
import '../widgets/profile_ui.dart';
import '../widgets/stockwise_ui.dart';
import 'barcode_scanner_screen.dart';

// Change the reusable product template without changing existing stock.
class EditInventoryBatchScreen extends StatefulWidget {
  const EditInventoryBatchScreen({
    super.key,
    required this.product,
    this.categoryStream,
    this.onSave,
    this.pickPhoto,
    this.scanBarcode,
  });

  final BarcodeProduct product;
  final Stream<List<StoreCategory>>? categoryStream;
  final Future<void> Function(InventoryCatalogueDraft)? onSave;
  final Future<XFile?> Function()? pickPhoto;
  final Future<String?> Function()? scanBarcode;

  @override
  State<EditInventoryBatchScreen> createState() =>
      _EditInventoryBatchScreenState();
}

class _EditInventoryBatchScreenState extends State<EditInventoryBatchScreen> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.product.name);
  late final barcode = TextEditingController(text: widget.product.barcode);
  late final unit = TextEditingController(text: widget.product.unitLabel);
  late final price = TextEditingController(
    text: (widget.product.basePriceCents / 100).toStringAsFixed(2),
  );
  late String category = widget.product.categoryId;
  late final categories =
      widget.categoryStream ?? FirestoreService.instance.watchCategoryRecords();
  XFile? image;
  Uint8List? preview;
  bool saving = false, picking = false, completed = false;
  String? error;

  bool get dirty =>
      name.text != widget.product.name ||
      barcode.text != widget.product.barcode ||
      unit.text != widget.product.unitLabel ||
      price.text != (widget.product.basePriceCents / 100).toStringAsFixed(2) ||
      category != widget.product.categoryId ||
      image != null;
  bool get allowed =>
      StoreSession.instance.canManage &&
      StoreSession.instance.storeId == widget.product.storeId;

  @override
  void initState() {
    super.initState();
    for (final controller in [name, barcode, unit, price]) {
      controller.addListener(_refresh);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final controller in [name, barcode, unit, price]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: StoreSession.instance,
    builder: (context, _) => ProfileFormPage(
      title: 'Edit Inventory Batch',
      dirty: dirty,
      busy: saving || picking,
      completed: completed,
      body: !allowed
          ? const Center(child: InventoryEmpty(title: 'Admin access required'))
          : InventoryTheme(
              enlargedFields: true,
              child: StreamBuilder<List<StoreCategory>>(
                stream: categories,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: InventoryEmpty(
                        title: 'Could not load categories',
                        body: 'Check your connection and reopen this page.',
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final choices = {
                    for (final record in snapshot.data!)
                      if (record.active ||
                          record.id == widget.product.categoryId)
                        record.id:
                            '${categoryTitleCase(record.name)}'
                            '${record.active ? '' : ' (archived)'}',
                  };
                  return Form(
                    key: form,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _photo(),
                                const SizedBox(height: 22),
                                _field(
                                  'catalogue-barcode',
                                  barcode,
                                  'Barcode',
                                  hint: 'Enter barcode',
                                  maxLength: 100,
                                  suffix: IconButton(
                                    tooltip: 'Scan barcode',
                                    onPressed: saving || picking ? null : _scan,
                                    icon: const Icon(
                                      Icons.qr_code_scanner_rounded,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                _field(
                                  'catalogue-name',
                                  name,
                                  'Name',
                                  hint: productNameHint,
                                  maxLength: 160,
                                  formatters: const [ProductNameFormatter()],
                                ),
                                const SizedBox(height: 18),
                                FormField<String>(
                                  key: ValueKey('catalogue-category-$category'),
                                  initialValue: choices.containsKey(category)
                                      ? category
                                      : null,
                                  validator: (value) =>
                                      choices.containsKey(value)
                                      ? null
                                      : 'Choose a category',
                                  builder: (field) => InkWell(
                                    key: const ValueKey('catalogue-category'),
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: saving || picking
                                        ? null
                                        : () async {
                                            FocusScope.of(context).unfocus();
                                            final selected =
                                                await showInventoryCategorySheet(
                                                  context: context,
                                                  choices: choices,
                                                  selected: category,
                                                  title: 'Category',
                                                );
                                            if (selected != null && mounted) {
                                              setState(
                                                () => category = selected,
                                              );
                                            }
                                          },
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: 'Category',
                                        errorText: field.errorText,
                                        suffixIcon: const Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                        ),
                                      ),
                                      child: Text(
                                        choices[category] ?? 'Select category',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: InventoryColors.muted,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                _field(
                                  'catalogue-unit',
                                  unit,
                                  'Unit',
                                  hint: 'e.g. pack, bottle, kg',
                                  maxLength: 40,
                                ),
                                const SizedBox(height: 18),
                                _field(
                                  'catalogue-price',
                                  price,
                                  'Regular Price',
                                  hint: '0.00',
                                  priceField: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              error!,
                              style: const TextStyle(
                                color: InventoryColors.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
      footer: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 18),
        child: InventoryButton(
          key: const ValueKey('save-catalogue-product'),
          label: saving ? 'Saving...' : 'Save Changes',
          busy: saving,
          onPressed: !allowed || saving || picking ? null : _save,
        ),
      ),
    ),
  );

  // Keep the same outlined fields as the inventory editor.
  Widget _field(
    String key,
    TextEditingController controller,
    String label, {
    required String hint,
    int? maxLength,
    Widget? suffix,
    bool priceField = false,
    List<TextInputFormatter>? formatters,
  }) => TextFormField(
    key: ValueKey(key),
    controller: controller,
    enabled: !saving && !picking,
    style: const TextStyle(fontSize: 14, color: InventoryColors.muted),
    textCapitalization: label == 'Name'
        ? TextCapitalization.words
        : TextCapitalization.none,
    keyboardType: priceField
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    inputFormatters:
        formatters ??
        (priceField
            ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
            : null),
    maxLength: maxLength,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      hintMaxLines: label == 'Name' ? 2 : 1,
      counterText: '',
      suffixIcon: suffix,
      prefixText: priceField ? 'RM ' : null,
    ),
    validator: (value) {
      final text = value?.trim() ?? '';
      if (text.isEmpty) return 'Enter ${label.toLowerCase()}';
      if (priceField) {
        final amount = double.tryParse(text);
        if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text) ||
            amount == null ||
            !amount.isFinite ||
            amount <= 0 ||
            amount > 10000000) {
          return 'Enter a valid price greater than zero';
        }
      }
      return null;
    },
  );

  Widget _photo() => Material(
    color: InventoryColors.background,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: InventoryColors.line),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: const ValueKey('catalogue-photo'),
      onTap: saving || picking ? null : _pickPhoto,
      child: Container(
        constraints: const BoxConstraints(minHeight: 150),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (preview != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  preview!,
                  width: 76,
                  height: 76,
                  fit: BoxFit.cover,
                ),
              )
            else if (widget.product.imagePath?.isNotEmpty ?? false)
              ProductArtwork(size: 76, imagePath: widget.product.imagePath)
            else
              const Icon(
                Icons.photo_outlined,
                size: 44,
                color: InventoryColors.green,
              ),
            const SizedBox(height: 12),
            Text(
              image != null || (widget.product.imagePath?.isNotEmpty ?? false)
                  ? 'Replace Photo'
                  : 'Choose Photo',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Optional / Photo library',
              style: TextStyle(fontSize: 10.5, color: InventoryColors.muted),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _pickPhoto() async {
    setState(() {
      picking = true;
      error = null;
    });
    try {
      final file =
          await (widget.pickPhoto?.call() ??
              ImagePicker().pickImage(
                source: ImageSource.gallery,
                imageQuality: 82,
                maxWidth: 1600,
              ));
      if (file == null) return;
      final upload = await ImageUpload.read(file);
      if (mounted) {
        setState(() {
          image = file;
          preview = upload.bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is ArgumentError
              ? e.message.toString()
              : 'Could not load this photo. Try another image.',
        );
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> _scan() async {
    setState(() => picking = true);
    try {
      final result =
          await (widget.scanBarcode?.call() ??
              Navigator.push<String>(
                context,
                MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
              ));
      if (result != null && mounted) barcode.text = result;
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not scan the barcode. Enter it manually.',
        );
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> _save() async {
    if (!allowed || form.currentState?.validate() != true) return;
    final draft = InventoryCatalogueDraft(
      product: widget.product,
      name: name.text,
      barcode: barcode.text,
      categoryId: category,
      unitLabel: unit.text,
      basePriceCents: (double.parse(price.text.trim()) * 100).round(),
      image: image,
    );
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await (widget.onSave ?? InventoryCatalogueService.instance.saveProduct)(
        draft,
      );
      if (!mounted) return;
      setState(() {
        completed = true;
        saving = false;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = e is StateError
              ? e.message
              : e is ArgumentError
              ? e.message.toString()
              : 'Could not save this product. Please try again.';
        });
      }
    }
  }
}
