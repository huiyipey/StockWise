import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_models.dart';
import '../models/category_label.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/stockwise_ui.dart';
import '../widgets/product_price.dart';

class ItemDetailScreen extends StatelessWidget {
  final InventoryBatch item;

  const ItemDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const StockWiseHeader(
            title: 'Product Details',
            leading: BackCircleButton(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: ProductArtwork(
                    size: 180,
                    imagePath: item.imagePath,
                    enlargeOnTap: true,
                    imageLabel: item.productName,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  item.productName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                ProductPrice(item: item, fontSize: 23, centered: true),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _row(
                          'Expiry',
                          DateFormat('dd MMM yyyy').format(item.expiryAt),
                        ),
                        _row(
                          'Available',
                          '${item.availableQuantity} ${item.unitLabel}',
                        ),
                        _row(
                          'Category',
                          categoryTitleCase(
                            item.categoryId.replaceAll('-', ' '),
                          ),
                        ),
                        if (item.barcode?.isNotEmpty == true)
                          _row('Barcode', item.barcode!),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: item.canSellAt(DateTime.now())
                      ? () => _add(context)
                      : null,
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: const Text('ADD TO CART'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Text(label, style: const TextStyle(color: AppColors.muted)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );

  Future<void> _add(BuildContext context) async {
    try {
      await FirestoreService.instance.addToCart(item);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Added to cart')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }
}
