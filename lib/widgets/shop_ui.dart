import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_models.dart';
import '../services/firestore_service.dart';
import 'inventory_ui.dart';
import 'customer_ui.dart';

class ShopAssistantBanner extends StatelessWidget {
  const ShopAssistantBanner({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: InventoryColors.soft,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              color: InventoryColors.green,
              size: 24,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ask StockWise',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Find a little help with your shop',
                    style: TextStyle(
                      fontSize: 11,
                      color: InventoryColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 19,
              color: InventoryColors.green,
            ),
          ],
        ),
      ),
    ),
  );
}

class ShopSectionTitle extends StatelessWidget {
  const ShopSectionTitle(this.title, {super.key, this.count, this.subtitle});
  final String title;
  final int? count;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
          ),
          if (count != null) const SizedBox(width: 10),
          if (count != null)
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 13,
                color: InventoryColors.muted,
              ),
            ),
        ],
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 4),
        Text(
          subtitle!,
          style: const TextStyle(fontSize: 12, color: InventoryColors.muted),
        ),
      ],
    ],
  );
}

class ShopStateCard extends StatelessWidget {
  const ShopStateCard({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.busy = false,
  });
  final IconData icon;
  final String title;
  final String? message, actionLabel;
  final VoidCallback? onAction;
  final bool busy;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      children: [
        CircleAvatar(
          radius: 29,
          backgroundColor: InventoryColors.soft,
          child: busy
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, size: 27, color: InventoryColors.green),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        if (message != null) ...[
          const SizedBox(height: 8),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: InventoryColors.muted,
            ),
          ),
        ],
        if (actionLabel != null) ...[
          const SizedBox(height: 20),
          InventoryButton(label: actionLabel!, onPressed: onAction, soft: true),
        ],
      ],
    ),
  );
}

class ShopProductCard extends StatelessWidget {
  const ShopProductCard({
    super.key,
    required this.item,
    required this.category,
    required this.onOpen,
    required this.onAdd,
    required this.now,
    this.busy = false,
    this.featured = false,
    this.image,
  });
  final InventoryBatch item;
  final String category;
  final VoidCallback onOpen, onAdd;
  final bool busy, featured;
  final DateTime now;
  final ImageProvider? image;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: featured ? _featured(context) : _grid(context),
      ),
    ),
  );

  Widget _featured(BuildContext context) => _layout(context, large: true);
  Widget _grid(BuildContext context) => _layout(context, large: false);
  Widget _layout(BuildContext context, {required bool large}) => Column(
    mainAxisSize: large ? MainAxisSize.max : MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (large)
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ShopProductPhoto(item: item, image: image),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAECD5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'PROMOTION',
                    style: TextStyle(
                      fontSize: 9,
                      color: InventoryColors.amber,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        )
      else
        AspectRatio(
          aspectRatio: 1.1,
          child: ShopProductPhoto(item: item, image: image),
        ),
      const SizedBox(height: 12),
      Text(
        category,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, color: InventoryColors.muted),
      ),
      const SizedBox(height: 4),
      Text(
        item.productName,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: large ? 17 : 15,
          height: 1.3,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 8),
      _price(),
      const SizedBox(height: 8),
      _expiry(),
      const SizedBox(height: 6),
      Text(
        '${item.availableQuantity} ${item.unitLabel} available',
        style: const TextStyle(fontSize: 11, color: InventoryColors.muted),
      ),
      if (item.bundlePromotion)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: PromotionDescription(item.promotionLabel, fontSize: 10),
        ),
      const SizedBox(height: 6),
      if (!large) const Spacer(),
      Align(alignment: Alignment.bottomRight, child: _addButton()),
    ],
  );

  Widget _price() => Wrap(
    spacing: 7,
    runSpacing: 3,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(
        'RM ${(item.sellingPriceCents / 100).toStringAsFixed(2)}',
        style: const TextStyle(
          fontSize: 17,
          color: InventoryColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
      if (item.promotionEnabled && item.promotionPriceCents != null)
        Text(
          'RM ${(item.basePriceCents / 100).toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 11,
            color: InventoryColors.muted,
            decoration: TextDecoration.lineThrough,
          ),
        ),
    ],
  );
  Widget _expiry() {
    final days = item.daysUntilExpiryFrom(now);
    return Row(
      children: [
        Icon(
          Icons.schedule_rounded,
          size: 13,
          color: days <= 7 ? InventoryColors.amber : InventoryColors.muted,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'Exp: ${DateFormat('d MMM yyyy').format(item.expiryAt)}',
            style: TextStyle(
              fontSize: 11,
              color: days <= 7 ? InventoryColors.amber : InventoryColors.muted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _addButton() => IconButton(
    key: ValueKey('shop-add-${item.id}'),
    tooltip: 'Add ${item.productName} to cart',
    onPressed: busy ? null : onAdd,
    style: IconButton.styleFrom(
      minimumSize: const Size.square(44),
      maximumSize: const Size.square(44),
      padding: const EdgeInsets.all(6),
    ),
    icon: CircleAvatar(
      radius: 16,
      backgroundColor: busy ? InventoryColors.soft : InventoryColors.green,
      child: busy
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.add_rounded, color: Colors.white, size: 20),
    ),
  );
}

class ShopProductPhoto extends StatefulWidget {
  const ShopProductPhoto({super.key, required this.item, this.image});
  final InventoryBatch item;
  final ImageProvider? image;
  @override
  State<ShopProductPhoto> createState() => _ShopProductPhotoState();
}

class _ShopProductPhotoState extends State<ShopProductPhoto> {
  late Future<String?> url;
  @override
  void initState() {
    super.initState();
    resolve();
  }

  @override
  void didUpdateWidget(ShopProductPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.imagePath != widget.item.imagePath ||
        oldWidget.image != widget.image) {
      resolve();
    }
  }

  void resolve() {
    final path = widget.item.imagePath;
    url = widget.image != null || path == null || path.isEmpty
        ? Future.value(null)
        : path.startsWith('http')
        ? Future.value(path)
        : FirestoreService.instance.imageUrl(path);
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: ColoredBox(
      color: const Color(0xFFF0F3ED),
      child: widget.image != null
          ? Image(
              image: widget.image!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder(),
            )
          : FutureBuilder<String?>(
              future: url,
              builder: (context, snapshot) => snapshot.data == null
                  ? placeholder()
                  : Image.network(
                      snapshot.data!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => placeholder(),
                    ),
            ),
    ),
  );
  Widget placeholder() => const Center(
    child: Icon(Icons.image_outlined, size: 37, color: Color(0xFFA3B39F)),
  );
}
