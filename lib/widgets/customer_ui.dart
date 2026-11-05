import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/app_models.dart';
import 'glass_bottom_nav.dart';
import 'inventory_ui.dart';

class PromotionDescription extends StatelessWidget {
  const PromotionDescription(this.text, {super.key, this.fontSize = 12});
  final String text;
  final double fontSize;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: InventoryColors.soft.withValues(alpha: .55),
      border: Border.all(color: InventoryColors.green.withValues(alpha: .3)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        color: InventoryColors.green,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

void showCustomerFeedback(
  BuildContext context,
  String message, {
  bool error = false,
  Widget? action,
  double bottomMargin = 18,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        persist: false,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(20, 12, 20, bottomMargin),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        elevation: 0,
        backgroundColor: error ? const Color(0xFFFAE7E0) : InventoryColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_rounded,
              size: 20,
              color: error ? InventoryColors.error : Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: error ? InventoryColors.error : Colors.white,
                ),
              ),
            ),
            if (action != null) ...[const SizedBox(width: 8), action],
          ],
        ),
      ),
    );
}

void showAddedToCartFeedback(
  BuildContext context,
  String productName, {
  required VoidCallback onViewCart,
}) => showCustomerFeedback(
  context,
  '$productName added to cart',
  bottomMargin: 6,
  action: TextButton(
    style: TextButton.styleFrom(
      foregroundColor: Colors.white,
      minimumSize: Size.zero,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    onPressed: () {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      onViewCart();
    },
    child: const Text(
      'View cart',
      style: TextStyle(
        fontSize: 13,
        decoration: TextDecoration.underline,
        decorationColor: Colors.white,
      ),
    ),
  ),
);

class CustomerBottomNav extends StatefulWidget {
  const CustomerBottomNav({
    super.key,
    required this.currentIndex,
    required this.items,
    this.cartCountStream,
    this.fontSize = 9.5,
  });
  final int currentIndex;
  final List<NavItem> items;
  final Stream<int>? cartCountStream;
  final double fontSize;
  @override
  State<CustomerBottomNav> createState() => _CustomerBottomNavState();
}

class _CustomerBottomNavState extends State<CustomerBottomNav> {
  late final Stream<int> source =
      widget.cartCountStream ??
      (Firebase.apps.isEmpty
          ? Stream.value(0)
          : FirestoreService.instance.watchCart().map(
              (lines) => lines.fold<int>(0, (sum, line) => sum + line.quantity),
            ));
  @override
  Widget build(BuildContext context) => StreamBuilder<int>(
    stream: source,
    builder: (context, snapshot) => InventoryBottomNav(
      currentIndex: widget.currentIndex,
      fontSize: widget.fontSize,
      items: [
        for (final item in widget.items)
          NavItem(
            icon: item.icon,
            activeIcon: item.activeIcon,
            label: item.label,
            onTap: item.onTap,
            badgeCount: item.label == 'Cart'
                ? snapshot.data ?? 0
                : item.badgeCount,
          ),
      ],
    ),
  );
}

class ProductPricingCard extends StatelessWidget {
  const ProductPricingCard({super.key, required this.item});
  final InventoryBatch item;
  String money(int cents) => 'RM ${(cents / 100).toStringAsFixed(2)}';
  @override
  Widget build(BuildContext context) {
    final discount = item.promotionEnabled && item.promotionPriceCents != null;
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
                if (item.promotionEnabled)
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
                    color: discount
                        ? InventoryColors.green
                        : InventoryColors.ink,
                  ),
                ),
                if (discount)
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
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: PromotionDescription(item.promotionLabel),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
