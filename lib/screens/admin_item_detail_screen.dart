import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../models/app_models.dart';
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
    this.onEdit,
    this.imageProvider,
  });

  final InventoryBatch item;
  final String? categoryName;
  final Future<void> Function()? onDiscard;
  final VoidCallback? onEdit;
  final ImageProvider? imageProvider;

  String get category =>
      categoryName ?? inventoryCategoryName(item.categoryId, const []);
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
                title: 'Item details',
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
                                    '${category.toUpperCase()} / per $priceUnit',
                                    key: const ValueKey('item-category-unit'),
                                    style: const TextStyle(
                                      fontSize: 9.5,
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
                    _stockBalance(),
                    const SizedBox(height: 16),
                    _expiry(context),
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
                label: 'Edit item',
                icon: Icons.edit_outlined,
                onPressed:
                    onEdit ??
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditItemScreen(item: item),
                      ),
                    ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _stockBalance() => Container(
    key: const ValueKey('item-stock-summary'),
    constraints: const BoxConstraints(minHeight: 122),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: InventoryColors.ink,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Quantity on hand',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFFC9DBCA),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          quantity,
          key: const ValueKey('stock-on-hand'),
          style: const TextStyle(
            fontSize: 33,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        if (item.quantityReserved > 0) ...[
          const SizedBox(height: 8),
          Text(
            '${item.quantityReserved} reserved for orders · ${item.availableQuantity} available',
            style: const TextStyle(fontSize: 11, color: Color(0xFFC9DBCA)),
          ),
        ],
      ],
    ),
  );

  Widget _expiry(BuildContext context) {
    final days = item.daysUntilExpiry;
    final status = days < 0
        ? 'Expired'
        : days == 0
        ? 'Today'
        : '$days ${days == 1 ? 'day' : 'days'} left';
    final color = days <= 2 ? InventoryColors.error : InventoryColors.amber;
    final badge = Container(
      key: const ValueKey('item-expiry-status'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: days <= 2 ? const Color(0xFFFAE7E0) : const Color(0xFFFAECD6),
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
    final date = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: InventoryColors.soft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.calendar_today_outlined,
            size: 20,
            color: InventoryColors.green,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Exp:',
                style: TextStyle(fontSize: 10.5, color: InventoryColors.muted),
              ),
              const SizedBox(height: 6),
              Text(
                DateFormat('dd MMM yyyy').format(item.expiryAt),
                key: const ValueKey('item-expiry-date'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return Card(
      key: const ValueKey('item-expiry-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: date),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * .45,
                ),
                child: badge,
              ),
            ],
          ),
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
            const SizedBox(height: 12),
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
            'Product information',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 22),
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
    final enabled = item.quantityOnHand > 0;
    final color = enabled ? InventoryColors.error : InventoryColors.muted;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.delete_outline_rounded, size: 21, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Discard remaining stock',
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
                  ? 'Record all $quantity as waste and close this batch.'
                  : 'There is no remaining stock to discard.',
              style: const TextStyle(
                fontSize: 11.5,
                color: InventoryColors.muted,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const ValueKey('item-discard'),
                onPressed: enabled ? () => _discard(context) : null,
                style: TextButton.styleFrom(
                  foregroundColor: InventoryColors.error,
                  disabledForegroundColor: InventoryColors.muted,
                  textStyle: TextStyle(
                    fontFamily: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(enabled ? 'Discard stock' : 'No remaining stock'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _discard(BuildContext context) async {
    final discarded = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => InventoryTheme(
        child: _DiscardStockDialog(
          item: item,
          onDiscard:
              onDiscard ??
              () => FirestoreService.instance.discardBatch(
                item,
                quantity: item.quantityOnHand,
              ),
        ),
      ),
    );
    if (discarded == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(inventoryFeedback('$quantity recorded as waste.'));
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
        height: 142,
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
  const _DiscardStockDialog({required this.item, required this.onDiscard});
  final InventoryBatch item;
  final Future<void> Function() onDiscard;
  @override
  State<_DiscardStockDialog> createState() => _DiscardStockDialogState();
}

class _DiscardStockDialogState extends State<_DiscardStockDialog> {
  bool saving = false;
  bool failed = false;

  Future<void> discard() async {
    if (saving) return;
    setState(() {
      saving = true;
      failed = false;
    });
    try {
      await widget.onDiscard();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFFFAE7E0),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: InventoryColors.error,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Discard remaining stock?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: SizedBox(
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'This records all remaining stock as waste and closes this batch.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: InventoryColors.muted,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: InventoryColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 16,
                runSpacing: 8,
                children: [
                  Text(
                    widget.item.productName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${widget.item.quantityOnHand} ${widget.item.unitLabel}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (failed) ...[
              const SizedBox(height: 16),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 17,
                    color: InventoryColors.error,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Could not discard stock. Please try again.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: InventoryColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
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
                onPressed: saving ? null : () => Navigator.pop(context, false),
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
