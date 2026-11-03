import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../models/app_models.dart';
import '../models/shelf_life.dart';
import '../models/category_label.dart';
import '../services/firestore_service.dart';
import '../widgets/inventory_ui.dart';
import 'edit_item_screen.dart';
import 'product_image_screen.dart';

class AdminItemDetailScreen extends StatelessWidget {
  const AdminItemDetailScreen({
    super.key,
    required this.item,
    this.categoryName,
    this.onDiscard,
    this.onDiscarded,
    this.onEdit,
    this.imageProvider,
    this.liveUpdates = false,
    this.inventoryStream,
    this.onDiscardQuantity,
  });
  final InventoryBatch item;
  final String? categoryName;
  final Future<void> Function()? onDiscard;
  final Future<void> Function(int)? onDiscardQuantity;
  final ValueChanged<String>? onDiscarded;
  final VoidCallback? onEdit;
  final ImageProvider? imageProvider;
  final bool liveUpdates;
  final Stream<InventoryBatch?>? inventoryStream;
  @override
  Widget build(BuildContext context) {
    Widget content(InventoryBatch value) => _InventoryDetails(
      item: value,
      categoryName: categoryName,
      onDiscard: onDiscard,
      onDiscarded: onDiscarded,
      onEdit: onEdit,
      imageProvider: imageProvider,
      onDiscardQuantity: onDiscardQuantity,
      updates: liveUpdates
          ? (inventoryStream ??
                FirestoreService.instance.watchInventoryBatch(item.id))
          : inventoryStream,
    );
    if (!liveUpdates && inventoryStream == null) return content(item);
    return StreamBuilder<InventoryBatch?>(
      stream:
          inventoryStream ??
          FirestoreService.instance.watchInventoryBatch(item.id),
      initialData: item,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return InventoryTheme(
            child: Scaffold(
              appBar: AppBar(title: const Text('Inventory Details')),
              body: const Center(
                child: Text('Could not refresh inventory. Reopen this page.'),
              ),
            ),
          );
        }
        if (snapshot.data == null) {
          return InventoryTheme(
            child: Scaffold(
              appBar: AppBar(title: const Text('Inventory Details')),
              body: const Center(
                child: Text('This inventory has been removed.'),
              ),
            ),
          );
        }
        return content(snapshot.data!);
      },
    );
  }
}

class _InventoryDetails extends StatelessWidget {
  const _InventoryDetails({
    required this.item,
    this.categoryName,
    this.onDiscard,
    this.onDiscarded,
    this.onEdit,
    this.imageProvider,
    this.onDiscardQuantity,
    this.updates,
  });

  final Stream<InventoryBatch?>? updates;
  final InventoryBatch item;
  final String? categoryName;
  final Future<void> Function()? onDiscard;
  final Future<void> Function(int)? onDiscardQuantity;
  final ValueChanged<String>? onDiscarded;
  final VoidCallback? onEdit;
  final ImageProvider? imageProvider;

  String get category => categoryTitleCase(
    categoryName ?? inventoryCategoryName(item.categoryId, const []),
  );
  String get quantity => '${item.quantityOnHand} ${item.unitLabel}';
  String get priceUnit =>
      const {
        'packs': 'pack',
        'bottles': 'bottle',
        'boxes': 'box',
        'loaves': 'loaf',
        'units': 'unit',
      }[item.unitLabel.toLowerCase()] ??
      item.unitLabel;
  String money(int cents) => 'RM ${(cents / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) => InventoryTheme(
    child: Builder(
      builder: (context) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              InventoryHeader(
                title: 'Inventory Details',
                back: true,
                onBack: () => Navigator.maybePop(context),
              ),
              Expanded(
                child: ListView(
                  key: const ValueKey('item-details-scroll'),
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                  children: [
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _ItemPhoto(
                              imagePath: item.imagePath,
                              imageProvider: imageProvider,
                              title: item.productName,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              key: const ValueKey('item-product-meta'),
                              children: [
                                Expanded(
                                  child: Text(
                                    '$category / Per $priceUnit',
                                    key: const ValueKey('item-category-unit'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: InventoryColors.green,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (item.quantityOnHand == 0) ...[
                                  const SizedBox(width: 12),
                                  Container(
                                    key: const ValueKey('item-out-of-stock'),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: InventoryColors.soft,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'Out of stock',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: InventoryColors.muted,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              item.productName,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: InventoryColors.ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _stockAndExpiry(),
                    const SizedBox(height: 16),
                    _pricing(),
                    const SizedBox(height: 16),
                    _details(),
                    const SizedBox(height: 16),
                    _discardCard(context),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: InventoryColors.line)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              child: InventoryButton(
                key: const ValueKey('item-details-edit'),
                label: 'Edit Inventory',
                icon: Icons.edit_outlined,
                onPressed: item.expiryAt.isAfter(DateTime.now())
                    ? (onEdit ??
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditItemScreen(item: item),
                            ),
                          ))
                    : null,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _stockAndExpiry() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      IntrinsicHeight(
        child: Row(
          key: const ValueKey('item-stock-expiry-summary'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _stockBalance()),
            const SizedBox(width: 12),
            Expanded(child: _expiry()),
          ],
        ),
      ),
      if (item.quantityReserved > 0) ...[
        const SizedBox(height: 10),
        Text(
          '${item.quantityReserved} reserved for orders · ${item.availableQuantity} available',
          style: const TextStyle(fontSize: 11, color: InventoryColors.muted),
        ),
      ],
    ],
  );

  Widget _summaryLine({required double minHeight, required Widget child}) =>
      ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Align(alignment: Alignment.centerLeft, child: child),
      );

  Widget _stockBalance() => Container(
    key: const ValueKey('item-stock-summary'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: InventoryColors.ink,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summaryLine(
          minHeight: 40,
          child: const Text(
            'Stock Available',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _summaryLine(
          minHeight: 40,
          child: Text(
            '${item.availableQuantity}',
            key: const ValueKey('stock-on-hand'),
            style: const TextStyle(
              fontSize: 33,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _summaryLine(
          minHeight: 26,
          child: Text(
            item.unitLabel,
            key: const ValueKey('stock-unit'),
            style: const TextStyle(fontSize: 11, color: Color(0xFFC9DBCA)),
          ),
        ),
      ],
    ),
  );

  Widget _expiry() {
    final days = item.daysUntilExpiry;
    final status = days < 0
        ? 'Expired'
        : days == 0
        ? 'Today'
        : '$days ${days == 1 ? 'day' : 'days'} left';
    final color = item.expiryColour == ShelfLifeColour.green
        ? InventoryColors.green
        : item.expiryColour == ShelfLifeColour.orange
        ? InventoryColors.amber
        : InventoryColors.error;
    final badge = Container(
      key: const ValueKey('item-expiry-status'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    final heading = Row(
      children: [
        const Expanded(
          child: Text(
            'Expiry Date',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: InventoryColors.ink,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: InventoryColors.soft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.access_time_rounded,
            size: 20,
            color: InventoryColors.green,
          ),
        ),
      ],
    );
    return Card(
      key: const ValueKey('item-expiry-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _summaryLine(minHeight: 40, child: heading),
            const SizedBox(height: 8),
            _summaryLine(
              minHeight: 40,
              child: Text(
                DateFormat('dd MMM yyyy').format(item.expiryAt),
                key: const ValueKey('item-expiry-date'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _summaryLine(minHeight: 26, child: badge),
          ],
        ),
      ),
    );
  }

  Widget _pricing() {
    final promotion = item.promotionEnabled && item.promotionPriceCents != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Pricing',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                if (promotion)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: InventoryColors.soft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Promotion',
                      style: TextStyle(
                        color: InventoryColors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  money(item.sellingPriceCents),
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    color: promotion
                        ? InventoryColors.green
                        : InventoryColors.ink,
                  ),
                ),
                if (promotion)
                  Text(
                    money(item.basePriceCents),
                    style: const TextStyle(
                      color: InventoryColors.muted,
                      fontSize: 12,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
              ],
            ),
            if (item.bundlePromotion)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  item.promotionLabel,
                  style: const TextStyle(
                    color: InventoryColors.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _details() => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Product Information',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _DetailRow(label: 'Category', value: category),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1),
          ),
          _DetailRow(
            label: 'Barcode',
            value: item.barcode?.isNotEmpty == true
                ? item.barcode!
                : 'Not added',
          ),
        ],
      ),
    ),
  );

  Widget _discardCard(BuildContext context) {
    final enabled = item.availableQuantity > 0;
    final color = enabled ? InventoryColors.error : InventoryColors.muted;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.delete_outline_rounded, size: 21, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Discard Stock',
                    style: TextStyle(
                      fontSize: 13,
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              enabled
                  ? 'Choose how much stock to record as waste.'
                  : 'There is no remaining stock to discard.',
              style: const TextStyle(
                fontSize: 11.5,
                color: InventoryColors.muted,
              ),
            ),
            const SizedBox(height: 12),
            InventoryButton(
              key: const ValueKey('item-discard'),
              label: enabled ? 'Discard Stock' : 'No remaining stock',
              icon: Icons.delete_outline_rounded,
              danger: true,
              height: 46,
              fontSize: 14,
              onPressed: enabled ? () => _discard(context) : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _discard(BuildContext context) async {
    final discarded = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => InventoryTheme(
        child: _DiscardStockDialog(
          item: item,
          updates: updates,
          onDiscard: (quantity) async {
            if (onDiscardQuantity != null) {
              await onDiscardQuantity!(quantity);
            } else if (onDiscard != null) {
              await onDiscard!();
            } else {
              await FirestoreService.instance.discardBatch(
                item,
                quantity: quantity,
              );
            }
          },
        ),
      ),
    );
    if (discarded != null && context.mounted) {
      showInventoryOverlayFeedback(
        context,
        '$discarded ${item.unitLabel} recorded as waste.',
      );
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        flex: 2,
        child: Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: InventoryColors.muted),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        flex: 3,
        child: SelectableText(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontSize: 12.5,
            color: InventoryColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class _ItemPhoto extends StatefulWidget {
  const _ItemPhoto({required this.title, this.imagePath, this.imageProvider});
  final String title;
  final String? imagePath;
  final ImageProvider? imageProvider;
  @override
  State<_ItemPhoto> createState() => _ItemPhotoState();
}

class _ItemPhotoState extends State<_ItemPhoto> {
  late final Future<ImageProvider?> image = _load();
  Future<ImageProvider?> _load() async {
    if (widget.imageProvider != null) return widget.imageProvider;
    final path = widget.imagePath;
    if (path == null || path.isEmpty) return null;
    final url = path.startsWith('http')
        ? path
        : await FirestoreService.instance.imageUrl(path);
    return url == null ? null : NetworkImage(url);
  }

  Widget placeholder() => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.photo_outlined, size: 42, color: InventoryColors.muted),
        SizedBox(height: 12),
        Text(
          'No photo added',
          style: TextStyle(fontSize: 11, color: InventoryColors.muted),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: ColoredBox(
      color: InventoryColors.background,
      child: SizedBox(
        key: const ValueKey('item-details-photo'),
        height: 166,
        width: double.infinity,
        child: FutureBuilder<ImageProvider?>(
          future: image,
          builder: (context, snapshot) {
            final provider = snapshot.data;
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (provider == null) return placeholder();
            return Image(
              image: provider,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => placeholder(),
              frameBuilder: (context, child, frame, synchronous) {
                if (frame == null && !synchronous) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Tooltip(
                  message: 'Enlarge image',
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => ProductImageScreen(
                          image: provider,
                          title: widget.title,
                          inventoryStyle: true,
                        ),
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        child,
                        Positioned(
                          right: 9,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(
                              Icons.fullscreen_rounded,
                              color: InventoryColors.green,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ),
  );
}

class _DiscardStockDialog extends StatefulWidget {
  const _DiscardStockDialog({
    required this.item,
    required this.onDiscard,
    this.updates,
  });
  final Stream<InventoryBatch?>? updates;
  final InventoryBatch item;
  final Future<void> Function(int) onDiscard;
  @override
  State<_DiscardStockDialog> createState() => _DiscardStockDialogState();
}

class _DiscardStockDialogState extends State<_DiscardStockDialog> {
  final form = GlobalKey<FormState>();
  final quantity = TextEditingController(text: '1');
  StreamSubscription<InventoryBatch?>? subscription;
  late int available = widget.item.availableQuantity;
  @override
  void initState() {
    super.initState();
    subscription = widget.updates?.listen((value) {
      if (mounted) setState(() => available = value?.availableQuantity ?? 0);
    });
  }

  bool saving = false;
  String? error;
  @override
  void dispose() {
    subscription?.cancel();
    quantity.dispose();
    super.dispose();
  }

  Future<void> discard() async {
    if (saving || !(form.currentState?.validate() ?? false)) return;
    final value = int.parse(quantity.text);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Discard'),
        content: Text(
          'Record $value ${widget.item.unitLabel} of ${widget.item.productName} as waste?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.onDiscard(value);
      if (mounted) Navigator.pop(context, value);
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = e is StateError
              ? e.message.toString()
              : 'Could not discard stock. Refresh and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      scrollable: true,
      title: const Text('Discard Stock'),
      content: SizedBox(
        width: 350,
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.item.productName),
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton(
                    onPressed: saving
                        ? null
                        : () {
                            final n = int.tryParse(quantity.text) ?? 1;
                            if (n > 1) {
                              setState(() => quantity.text = '${n - 1}');
                            }
                          },
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('discard-quantity'),
                      controller: quantity,
                      enabled: !saving,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        return n == null || n < 1 || n > available
                            ? 'Enter 1–$available'
                            : null;
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: saving
                        ? null
                        : () {
                            final n = int.tryParse(quantity.text) ?? 0;
                            if (n < available) {
                              setState(() => quantity.text = '${n + 1}');
                            }
                          },
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '$available ${widget.item.unitLabel} available. Availability is checked again when saving.',
              ),
              if (error != null)
                Text(
                  error!,
                  style: const TextStyle(color: InventoryColors.error),
                ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
      actions: [
        Row(
          children: [
            Expanded(
              child: InventoryButton(
                label: 'Cancel',
                soft: true,
                onPressed: saving ? null : () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: InventoryButton(
                label: saving ? 'Discarding...' : 'Discard',
                danger: true,
                busy: saving,
                onPressed: saving ? null : discard,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
