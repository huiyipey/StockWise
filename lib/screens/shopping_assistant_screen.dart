import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/firestore_service.dart';
import '../services/store_session.dart';
import '../services/shopping_assistant_service.dart';
import '../widgets/inventory_ui.dart';
import '../widgets/shop_ui.dart';
import '../widgets/profile_ui.dart' show ProfilePanel, ProfileNotice;
import 'item_detail_screen.dart';

class ShoppingAssistantScreen extends StatefulWidget {
  final Stream<List<InventoryBatch>>? inventoryStream;
  final AssistantRequester? onAsk;
  const ShoppingAssistantScreen({super.key, this.inventoryStream, this.onAsk});
  @override
  State<ShoppingAssistantScreen> createState() =>
      _ShoppingAssistantScreenState();
}

class _ShoppingAssistantScreenState extends State<ShoppingAssistantScreen> {
  final question = TextEditingController();
  final scroll = ScrollController();
  final latestMessage = GlobalKey();
  final List<Map<String, String>> messages = [];
  final List<Map<String, String>> conversation = [];
  final selected = <String>{};
  List<Map<String, dynamic>> picks = [];
  late final inventory =
      widget.inventoryStream ?? FirestoreService.instance.watchInventory();
  bool busy = false, started = false;
  @override
  void dispose() {
    question.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> _ask([String? prompt]) async {
    if (busy) return;
    final text = prompt ?? question.text.trim();
    FocusScope.of(context).unfocus();
    if (scroll.hasClients) scroll.jumpTo(0);
    setState(() {
      busy = true;
      started = true;
      if (text.isNotEmpty) messages.add({'role': 'You', 'text': text});
    });
    try {
      final previous = recentAssistantConversation(conversation);
      final Map<String, dynamic> data;
      if (widget.onAsk != null) {
        data = await widget.onAsk!(
          question: text,
          productIds: selected.toList(),
          conversation: previous,
        );
      } else {
        final storeId = StoreSession.instance.storeId;
        if (storeId == null) throw StateError('Select a store first.');
        data = await askShoppingAssistant(
          storeId: storeId,
          question: text,
          productIds: selected.toList(),
          conversation: previous,
        );
      }
      if (!mounted) return;
      setState(() {
        picks = (data['recommendations'] as List)
            .map((v) => Map<String, dynamic>.from(v as Map))
            .toList();
        messages.add({'role': 'StockWise', 'text': data['answer'] as String});
        if (text.isNotEmpty && data['aiAvailable'] == true) {
          conversation.addAll([
            {'role': 'user', 'text': text},
            {'role': 'model', 'text': data['answer'] as String},
          ]);
          if (prompt == null && question.text.trim() == text) question.clear();
        }
      });
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        setState(
          () => messages.add({
            'role': 'StockWise',
            'error': 'true',
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
            'error': 'true',
            'text': 'Something went wrong. Please try again.',
          }),
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final target = latestMessage.currentContext;
          if (mounted && target != null) {
            Scrollable.ensureVisible(
              target,
              duration: const Duration(milliseconds: 250),
              alignment: .1,
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => InventoryTheme(
    child: Builder(
      builder: (context) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              InventoryHeader(
                title: 'Ask StockWise',
                back: true,
                onBack: () => Navigator.maybePop(context),
                trailing: IconButton(
                  tooltip: 'How your data is used',
                  onPressed: () => _showPrivacy(context),
                  icon: const Icon(
                    Icons.info_outline_rounded,
                    color: InventoryColors.green,
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<InventoryBatch>>(
                  stream: inventory,
                  builder: (context, snapshot) {
                    final products = (snapshot.data ?? <InventoryBatch>[])
                        .where((p) => p.canSellAt(DateTime.now()))
                        .toList();
                    final ids = products.map((p) => p.id).toSet();
                    // Removed/expired products cannot stay selected for a comparison.
                    selected.removeWhere((id) => !ids.contains(id));
                    return ListView(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      children: [
                        if (messages.isEmpty) ...[
                          ProfilePanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const CircleAvatar(
                                  radius: 24,
                                  backgroundColor: InventoryColors.soft,
                                  child: Icon(
                                    Icons.auto_awesome_rounded,
                                    color: InventoryColors.green,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Ask StockWise anything',
                                  style: TextStyle(
                                    fontSize: 23,
                                    height: 1.2,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Get suggestions from your recent purchases, compare products, or ask Gemini general questions.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                    color: InventoryColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                InventoryButton(
                                  label: started
                                      ? 'Refresh recommendations'
                                      : 'Show recommendations',
                                  onPressed: busy ? null : () => _ask(''),
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () => _showPrivacy(context),
                                  icon: const Icon(
                                    Icons.shield_outlined,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'How your data is used',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        ...messages.map(_messageCard),
                        if (busy)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 14),
                            child: ProfileNotice(
                              'StockWise is thinking...',
                              busy: true,
                            ),
                          ),
                        if (picks.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Recommended for you',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...picks.map((pick) {
                            final product = products
                                .where((p) => p.id == pick['id'])
                                .firstOrNull;
                            if (product == null) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: ProfilePanel(
                                padding: 0,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(22),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ItemDetailScreen(item: product),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 60,
                                          height: 78,
                                          child: ShopProductPhoto(
                                            item: product,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                product.productName,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                '${pick['reason']}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  height: 1.4,
                                                  color: InventoryColors.muted,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                'RM ${(product.sellingPriceCents / 100).toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: InventoryColors.green,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.chevron_right_rounded,
                                          size: 19,
                                          color: InventoryColors.muted,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                        if (messages.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          InventoryButton(
                            label: 'Refresh recommendations',
                            soft: true,
                            onPressed: busy ? null : () => _ask(''),
                          ),
                          const SizedBox(height: 16),
                        ],
                        ProfilePanel(
                          padding: 0,
                          child: Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 5,
                              ),
                              childrenPadding: const EdgeInsets.fromLTRB(
                                8,
                                0,
                                8,
                                12,
                              ),
                              iconColor: InventoryColors.green,
                              title: Text(
                                'Select products to compare (${selected.length}/2)',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              children: [
                                if (snapshot.hasError)
                                  const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: ProfileNotice(
                                      'Could not load products. Try opening the assistant again.',
                                      error: true,
                                    ),
                                  )
                                else if (!snapshot.hasData)
                                  const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: LinearProgressIndicator(),
                                  )
                                else if (products.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text(
                                      'No products available to compare.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: InventoryColors.muted,
                                      ),
                                    ),
                                  )
                                else
                                  SizedBox(
                                    height: 220,
                                    child: ListView(
                                      children: products
                                          .map(
                                            (p) => CheckboxListTile(
                                              value: selected.contains(p.id),
                                              activeColor:
                                                  InventoryColors.green,
                                              title: Text(
                                                p.productName,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              subtitle: Text(
                                                'RM ${(p.sellingPriceCents / 100).toStringAsFixed(2)} / ${p.unitLabel}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: InventoryColors.muted,
                                                ),
                                              ),
                                              onChanged:
                                                  busy ||
                                                      (!selected.contains(
                                                            p.id,
                                                          ) &&
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
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ActionChip(
                              backgroundColor: Colors.white,
                              side: BorderSide.none,
                              label: const Text(
                                'What should I buy?',
                                style: TextStyle(fontSize: 12),
                              ),
                              onPressed: busy
                                  ? null
                                  : () => _ask(
                                      'What should I buy based on my purchases?',
                                    ),
                            ),
                            ActionChip(
                              backgroundColor: Colors.white,
                              side: BorderSide.none,
                              label: const Text(
                                'Compare selected products',
                                style: TextStyle(fontSize: 12),
                              ),
                              onPressed: busy || selected.length != 2
                                  ? null
                                  : () => _ask(
                                      'What is the difference between these two selected products?',
                                    ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: question,
                        maxLength: 1000,
                        minLines: 1,
                        maxLines: 3,
                        enabled: !busy,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Ask StockWise anything...',
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Send question',
                      onPressed: busy
                          ? null
                          : () {
                              if (question.text.trim().isNotEmpty) _ask();
                            },
                      style: IconButton.styleFrom(
                        backgroundColor: InventoryColors.green,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: InventoryColors.soft,
                        minimumSize: const Size.square(46),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 21),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  void _showPrivacy(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (context) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.shield_outlined,
              size: 32,
              color: InventoryColors.green,
            ),
            const SizedBox(height: 18),
            const Text(
              'How your data is used',
              style: TextStyle(
                fontSize: 22,
                color: InventoryColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Your questions, recent conversation, store product details and purchased product names are sent to Google’s AI service. Your account email, delivery address and receipts are not included automatically. Answers may be inaccurate; check product labels for ingredients and allergens.',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: InventoryColors.muted,
              ),
            ),
            const SizedBox(height: 24),
            InventoryButton(
              label: 'Got it',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _messageCard(Map<String, String> message) {
    final user = message['role'] == 'You';
    final failed = message['error'] == 'true';
    return Padding(
      key: identical(message, messages.last) ? latestMessage : null,
      padding: EdgeInsets.only(
        bottom: 12,
        left: user ? 30 : 0,
        right: user ? 0 : 20,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: failed
              ? const Color(0xFFFAE7E0)
              : user
              ? InventoryColors.soft
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message['role']!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: failed ? InventoryColors.error : InventoryColors.green,
              ),
            ),
            const SizedBox(height: 7),
            SelectableText(
              message['text']!,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: failed ? InventoryColors.error : InventoryColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
