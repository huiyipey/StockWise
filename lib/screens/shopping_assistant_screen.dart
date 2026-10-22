import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/firestore_service.dart';
import '../services/store_session.dart';
import '../theme/app_theme.dart';
import '../widgets/stockwise_ui.dart';
import 'item_detail_screen.dart';

class ShoppingAssistantScreen extends StatefulWidget {
  const ShoppingAssistantScreen({super.key});
  @override
  State<ShoppingAssistantScreen> createState() =>
      _ShoppingAssistantScreenState();
}

class _ShoppingAssistantScreenState extends State<ShoppingAssistantScreen> {
  final question = TextEditingController();
  final List<Map<String, String>> messages = [];
  final selected = <String>{};
  List<Map<String, dynamic>> picks = [];
  late final inventory = FirestoreService.instance.watchInventory();
  bool busy = false, started = false;
  @override
  void dispose() {
    question.dispose();
    super.dispose();
  }

  Future<void> _ask([String? prompt]) async {
    if (busy) return;
    final text = prompt ?? question.text.trim();
    setState(() {
      busy = true;
      started = true;
      if (text.isNotEmpty) messages.add({'role': 'You', 'text': text});
    });
    question.clear();
    try {
      final response =
          await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
              .httpsCallable(
                'shoppingAssistant',
                options: HttpsCallableOptions(
                  timeout: const Duration(seconds: 120),
                ),
              )
              .call({
                'storeId': StoreSession.instance.storeId,
                'question': text,
                'productIds': selected.toList(),
              });
      if (!mounted) return;
      final data = Map<String, dynamic>.from(response.data as Map);
      setState(() {
        picks = (data['recommendations'] as List)
            .map((v) => Map<String, dynamic>.from(v as Map))
            .toList();
        messages.add({'role': 'StockWise', 'text': data['answer'] as String});
      });
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        setState(
          () => messages.add({
            'role': 'StockWise',
            'text': error.code == 'resource-exhausted'
                ? 'You have reached this hour’s limit. Please try again later.'
                : 'I could not connect. Please try again shortly.',
          }),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => messages.add({
            'role': 'StockWise',
            'text': 'Something went wrong. Please try again.',
          }),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const StockWiseHeader(
            title: 'Shopping Assistant',
            leading: BackCircleButton(),
          ),
          Expanded(
            child: StreamBuilder<List<InventoryBatch>>(
              stream: inventory,
              builder: (context, snapshot) {
                final products = (snapshot.data ?? <InventoryBatch>[])
                    .where(
                      (p) =>
                          p.status == 'active' &&
                          p.availableQuantity > 0 &&
                          p.expiryAt.isAfter(DateTime.now()),
                    )
                    .toList();
                return ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              color: AppColors.primaryDark,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Find your next favourite',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const Text(
                              'Get suggestions from your recent purchases in this store, or select two products and ask how they compare.',
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'When you ask, your question, product details and purchased product names are sent to Google’s AI service. Addresses, emails and receipts are excluded. Answers may be inaccurate; check the label for ingredients and allergens.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 10),
                            FilledButton(
                              onPressed: busy ? null : () => _ask(''),
                              child: Text(
                                started
                                    ? 'Refresh recommendations'
                                    : 'Show recommendations',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (picks.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Recommended for you',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      ...picks.map((pick) {
                        final product = products
                            .where((p) => p.id == pick['id'])
                            .firstOrNull;
                        if (product == null) return const SizedBox.shrink();
                        return Card(
                          child: ListTile(
                            leading: ProductArtwork(
                              size: 48,
                              imagePath: product.imagePath,
                            ),
                            title: Text(product.productName),
                            subtitle: Text(
                              '${pick['reason']}\nRM ${(product.sellingPriceCents / 100).toStringAsFixed(2)}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ItemDetailScreen(item: product),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 14),
                    ExpansionTile(
                      title: Text(
                        'Select products to compare (${selected.length}/2)',
                      ),
                      children: [
                        if (snapshot.hasError)
                          const Text('Could not load products.'),
                        if (!snapshot.hasData) const LinearProgressIndicator(),
                        SizedBox(
                          height: 220,
                          child: ListView(
                            children: products
                                .map(
                                  (p) => CheckboxListTile(
                                    value: selected.contains(p.id),
                                    title: Text(p.productName),
                                    subtitle: Text(
                                      'RM ${(p.sellingPriceCents / 100).toStringAsFixed(2)} • ${p.unitLabel}',
                                    ),
                                    onChanged:
                                        busy ||
                                            (!selected.contains(p.id) &&
                                                selected.length >= 2)
                                        ? null
                                        : (v) => setState(() {
                                            if (v == true) {
                                              selected.add(p.id);
                                            } else {
                                              selected.remove(p.id);
                                            }
                                          }),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        ActionChip(
                          label: const Text('What should I buy?'),
                          onPressed: busy
                              ? null
                              : () => _ask(
                                  'What should I buy based on my purchases?',
                                ),
                        ),
                        ActionChip(
                          label: const Text('Compare selected products'),
                          onPressed: busy || selected.length != 2
                              ? null
                              : () => _ask(
                                  'What is the difference between these two selected products?',
                                ),
                        ),
                      ],
                    ),
                    ...messages.map(
                      (m) => Card(
                        color: m['role'] == 'You'
                            ? AppColors.primarySoft
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m['role']!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 5),
                              SelectableText(m['text']!),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (busy)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: question,
                    maxLength: 1000,
                    minLines: 1,
                    maxLines: 3,
                    enabled: !busy,
                    decoration: const InputDecoration(
                      hintText: 'Ask about a product…',
                      counterText: '',
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Send question',
                  onPressed: busy
                      ? null
                      : () {
                          if (question.text.trim().isNotEmpty) _ask();
                        },
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
