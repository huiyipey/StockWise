import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../theme/app_theme.dart';

class ProductPrice extends StatelessWidget {
  final InventoryBatch item;
  final double fontSize;
  final bool centered;

  const ProductPrice({
    super.key,
    required this.item,
    this.fontSize = 16,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    final sellingPrice =
        'RM ${(item.sellingPriceCents / 100).toStringAsFixed(2)}';
    final price = Text(
      sellingPrice,
      style: TextStyle(
        color: AppColors.primaryDark,
        fontWeight: FontWeight.w900,
        fontSize: fontSize,
      ),
    );
    if (!item.promotionEnabled || item.promotionPriceCents == null) {
      return centered ? Center(child: price) : price;
    }
    final originalPrice =
        'RM ${(item.basePriceCents / 100).toStringAsFixed(2)}';
    return Semantics(
      label: 'Promotion price $sellingPrice. Original price $originalPrice.',
      child: ExcludeSemantics(
        child: Wrap(
          alignment: centered ? WrapAlignment.center : WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 2,
          children: [
            price,
            Text(
              originalPrice,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: fontSize * .75,
                decoration: TextDecoration.lineThrough,
                decorationColor: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
