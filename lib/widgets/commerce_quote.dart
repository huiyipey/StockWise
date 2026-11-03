import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import 'inventory_ui.dart';
import 'order_ui.dart';

List<Map<String, dynamic>> promotionWarnings(Map<String, dynamic>? quote) => [
  for (final value in quote?['promotionWarnings'] as List? ?? const [])
    if (value is Map) Map<String, dynamic>.from(value),
];

Map? cartQuoteSummary(Map<String, dynamic>? quote, String batchId) {
  for (final value in quote?['cartSummaries'] as List? ?? const []) {
    if (value is Map && value['batchId'] == batchId) return value;
  }
  return null;
}

Future<bool> confirmUnavailablePromotions(
  BuildContext context,
  Map<String, dynamic> quote, {
  bool includesDelivery = false,
}) async {
  final warnings = promotionWarnings(quote);
  if (warnings.isEmpty) return true;
  return await showDialog<bool>(
        context: context,
        builder: (context) => InventoryTheme(
          child: AlertDialog(
            title: Text(
              warnings.length == 1
                  ? 'Promotion Unavailable'
                  : 'Promotions Unavailable',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final warning in warnings) ...[
                    Text(
                      '${warning['message'] ?? warning['promotionLabel']}',
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text(
                    'Continue without these offers? Selected items will use their prices without the unavailable offers. Unavailable extra free items will be left out.',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${includesDelivery ? 'Revised total' : 'Revised subtotal'}: ${orderMoney(((quote[includesDelivery ? 'totalCents' : 'subtotalCents'] as num?) ?? 0).toInt())}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Back to Edit Cart'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue Without Offer'),
              ),
            ],
          ),
        ),
      ) ??
      false;
}

class QuoteLines extends StatelessWidget {
  const QuoteLines({super.key, this.quote});
  final Map<String, dynamic>? quote;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final raw in (quote?['lines'] as List? ?? const []))
        if (raw is Map &&
            raw['kind'] == 'bundle' &&
            (raw['automaticReward'] == true ||
                raw['automaticReward'] == null &&
                    raw['sourceBatchId'] != raw['batchId']) &&
            (raw['unitPriceCents'] ?? raw['lineTotalCents'] ?? 0) == 0)
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
