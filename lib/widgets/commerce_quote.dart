import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import 'inventory_ui.dart';
import 'order_ui.dart';

class QuoteLines extends StatelessWidget {
  const QuoteLines({super.key, this.quote});
  final Map<String, dynamic>? quote;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final raw in (quote?['lines'] as List? ?? const []))
        if (raw is Map && raw['kind'] == 'bundle')
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: OrderPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${raw['productName']} × ${raw['quantity']}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${raw['promotionLabel']}',
                    style: const TextStyle(
                      color: InventoryColors.green,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(orderMoney((raw['lineTotalCents'] as num).toInt())),
                ],
              ),
            ),
          ),
    ],
  );
}

class CartQuote extends StatefulWidget {
  const CartQuote({super.key, required this.revision});
  final String revision;
  @override
  State<CartQuote> createState() => _CartQuoteState();
}

class _CartQuoteState extends State<CartQuote> {
  late Future<Map<String, dynamic>> quote = FirestoreService.instance.quoteCart(
    '',
  );
  @override
  void didUpdateWidget(CartQuote oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) {
      quote = FirestoreService.instance.quoteCart('');
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: quote,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const OrderNotice(
          'Could not calculate live pricing. Open checkout to refresh your order.',
          error: true,
        );
      }
      if (!snapshot.hasData) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return Column(
        children: [
          QuoteLines(quote: snapshot.data),
          const SizedBox(height: 12),
          OrderTotals(
            subtotal: (snapshot.data!['subtotalCents'] as num).toInt(),
          ),
          const SizedBox(height: 8),
          const Text(
            'Delivery is calculated at checkout.',
            style: TextStyle(fontSize: 12, color: InventoryColors.muted),
          ),
        ],
      );
    },
  );
}
