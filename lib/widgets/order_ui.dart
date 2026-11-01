import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_models.dart';
import '../models/order_status.dart';
import 'inventory_ui.dart';

String orderMoney(int cents) => 'RM ${(cents / 100).toStringAsFixed(2)}';

class OrderPanel extends StatelessWidget {
  const OrderPanel({super.key, required this.child, this.padding = 18});
  final Widget child;
  final double padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
    ),
    child: child,
  );
}

class OrderHeading extends StatelessWidget {
  const OrderHeading(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 12),
    child: Text(
      text,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
    ),
  );
}

class OrderBadge extends StatelessWidget {
  const OrderBadge(this.label, {super.key, this.value = 'paid'});
  final String label, value;
  @override
  Widget build(BuildContext context) {
    final warning = value == 'unpaid' || value == 'to_pay';
    final error = value == 'cancelled';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: error
            ? const Color(0xFFFAE7E0)
            : warning
            ? const Color(0xFFFBECD6)
            : InventoryColors.soft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: error
              ? InventoryColors.error
              : warning
              ? InventoryColors.amber
              : InventoryColors.green,
        ),
      ),
    );
  }
}

class OrderStatusFilter extends StatelessWidget {
  const OrderStatusFilter({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final String selected;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final value in ['all', ...orderStatuses]) ...[
          if (value != 'all') const SizedBox(width: 7),
          Semantics(
            selected: value == selected,
            child: TextButton(
              key: ValueKey('order-filter-$value'),
              onPressed: () => onSelected(value),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                shape: const StadiumBorder(),
                foregroundColor: selected == value
                    ? InventoryColors.green
                    : InventoryColors.muted,
                backgroundColor: selected == value
                    ? InventoryColors.soft
                    : Colors.white,
                textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              child: Text(value == 'all' ? 'All' : orderLabel(value)),
            ),
          ),
        ],
      ],
    ),
  );
}

class OrderListCard extends StatelessWidget {
  const OrderListCard({super.key, required this.order, required this.onTap});
  final StoreOrder order;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        key: ValueKey('order-${order.id}'),
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (MediaQuery.textScalerOf(context).scale(12) > 16) ...[
                _number(),
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: _badges()),
              ] else
                Row(
                  children: [
                    Expanded(child: _number()),
                    const SizedBox(width: 8),
                    _badges().first,
                    const SizedBox(width: 6),
                    _badges().last,
                  ],
                ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Icon(
                    order.fulfillmentType == 'pickup'
                        ? Icons.storefront_outlined
                        : Icons.local_shipping_outlined,
                    size: 17,
                    color: InventoryColors.muted,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '${orderLabel(order.fulfillmentType)} / ${DateFormat('d MMM yyyy').format(order.placedAt)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: InventoryColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      orderMoney(order.totalCents),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: InventoryColors.muted,
                    size: 22,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _number() => Text(
    '#${order.orderNumber}',
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
  );
  List<Widget> _badges() => [
    OrderBadge(orderLabel(order.paymentStatus), value: order.paymentStatus),
    OrderBadge(orderLabel(order.status), value: order.status),
  ];
}

class OrderValueRow extends StatelessWidget {
  const OrderValueRow(this.label, this.value, {super.key, this.bold = false});
  final String label, value;
  final bool bold;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: bold ? InventoryColors.ink : InventoryColors.muted,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ],
    ),
  );
}

class OrderTotals extends StatelessWidget {
  const OrderTotals({super.key, required this.subtotal, this.delivery});
  final int subtotal;
  final int? delivery;
  @override
  Widget build(BuildContext context) => OrderPanel(
    child: Column(
      children: [
        OrderValueRow('Subtotal', orderMoney(subtotal), bold: delivery == null),
        if (delivery != null) ...[
          OrderValueRow('Delivery fee', orderMoney(delivery!)),
          const Divider(height: 20),
          OrderValueRow('Total', orderMoney(subtotal + delivery!), bold: true),
        ],
      ],
    ),
  );
}

class OrderNotice extends StatelessWidget {
  const OrderNotice(this.message, {super.key, this.error = false});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: error ? const Color(0xFFFAE7E0) : InventoryColors.soft,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 18,
          color: error ? InventoryColors.error : InventoryColors.green,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: error ? InventoryColors.error : InventoryColors.green,
            ),
          ),
        ),
      ],
    ),
  );
}

class OrderEmpty extends StatelessWidget {
  const OrderEmpty(
    this.title, {
    super.key,
    this.icon = Icons.receipt_long_outlined,
    this.onRetry,
  });
  final String title;
  final IconData icon;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: InventoryColors.soft,
          child: Icon(icon, size: 29, color: InventoryColors.green),
        ),
        const SizedBox(height: 22),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 12),
          const Text(
            'Check your connection and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: InventoryColors.muted),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 220,
            child: InventoryButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ),
        ],
      ],
    ),
  );
}

class OrderPickerField extends StatelessWidget {
  const OrderPickerField({
    super.key,
    this.label,
    required this.value,
    required this.onTap,
  });
  final String? label;
  final String value;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        isEmpty: false,
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: label == null
              ? FloatingLabelBehavior.never
              : FloatingLabelBehavior.always,
          constraints: BoxConstraints(minHeight: label == null ? 48 : 58),
          contentPadding: label == null
              ? const EdgeInsets.symmetric(horizontal: 14, vertical: 12)
              : null,
          suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
        ),
        child: Text(value, style: const TextStyle(fontSize: 13)),
      ),
    ),
  );
}

Future<String?> showOrderChoices({
  required BuildContext context,
  required String title,
  required Map<String, String> choices,
  required String selected,
  Map<String, String> disabled = const {},
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  backgroundColor: InventoryColors.background,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(27)),
  ),
  clipBehavior: Clip.antiAlias,
  builder: (context) => InventoryTheme(
    child: SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .78,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 58,
                  height: 4,
                  decoration: BoxDecoration(
                    color: InventoryColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  color: InventoryColors.ink,
                ),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: choices.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final entry = choices.entries.elementAt(index);
                    final blocked = disabled[entry.key];
                    return Semantics(
                      selected: selected == entry.key,
                      child: Material(
                        color: selected == entry.key
                            ? InventoryColors.soft
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          key: ValueKey('order-choice-${entry.key}'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: blocked != null
                              ? null
                              : () => Navigator.pop(context, entry.key),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 15,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.value,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: selected == entry.key
                                              ? FontWeight.w700
                                              : FontWeight.w400,
                                          color: blocked != null
                                              ? InventoryColors.muted
                                              : InventoryColors.green,
                                        ),
                                      ),
                                      if (blocked != null) ...[
                                        const SizedBox(height: 5),
                                        Text(
                                          blocked,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: InventoryColors.muted,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (selected == entry.key)
                                  const Icon(
                                    Icons.check_rounded,
                                    size: 19,
                                    color: InventoryColors.green,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

Future<bool> showOrderConfirmation({
  required BuildContext context,
  required String title,
  required String message,
  required String action,
  String cancel = 'Keep editing',
  bool danger = false,
  bool single = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => InventoryTheme(
        child: Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: InventoryColors.ink,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: InventoryColors.muted,
                    ),
                  ),
                  const SizedBox(height: 36),
                  Row(
                    children: [
                      if (!single) ...[
                        Expanded(
                          child: InventoryButton(
                            label: cancel,
                            soft: true,
                            height: 46,
                            onPressed: () => Navigator.pop(context, false),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: InventoryButton(
                          label: action,
                          danger: danger,
                          height: 46,
                          onPressed: () => Navigator.pop(context, true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ) ??
    false;
