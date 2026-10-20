import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_models.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/stockwise_ui.dart';
import 'edit_item_screen.dart';

class AdminItemDetailScreen extends StatelessWidget {
  final InventoryBatch item;

  const AdminItemDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const StockWiseHeader(
            title: 'Item Details',
            leading: BackCircleButton(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Center(
                  child: ProductArtwork(size: 150, imagePath: item.imagePath),
                ),
                const SizedBox(height: 18),
                Text(
                  item.productName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
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
                          'Quantity',
                          '${item.quantityOnHand} ${item.unitLabel}',
                        ),
                        _row('Available', '${item.availableQuantity}'),
                        _row('Category', item.categoryId.replaceAll('-', ' ')),
                        _row('Regular price', _money(item.basePriceCents)),
                        if (item.promotionEnabled)
                          _row(
                            'Promotion price',
                            _money(item.sellingPriceCents),
                          ),
                        if (item.barcode?.isNotEmpty == true)
                          _row('Barcode', item.barcode!),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: item.quantityOnHand > 0
                      ? () => _consume(context)
                      : null,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('MARK ONE AS CONSUMED'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditItemScreen(item: item),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('EDIT ITEM'),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                  onPressed: item.quantityOnHand > 0
                      ? () => _discard(context)
                      : null,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('DISCARD REMAINING STOCK'),
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
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );

  String _money(int cents) => 'RM ${(cents / 100).toStringAsFixed(2)}';

  Future<void> _consume(BuildContext context) async {
    try {
      await FirestoreService.instance.consumeBatch(item);
      if (context.mounted) Navigator.pop(context);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _discard(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard remaining stock?'),
        content: Text(
          'This records ${item.quantityOnHand} ${item.unitLabel} as waste and closes the batch.',
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
    if (confirmed != true) return;
    try {
      await FirestoreService.instance.discardBatch(
        item,
        quantity: item.quantityOnHand,
      );
      if (context.mounted) Navigator.pop(context);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }
}
