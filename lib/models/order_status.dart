const orderStatuses = [
  'to_pay',
  'to_ship',
  'to_receive',
  'completed',
  'cancelled',
];

String orderLabel(String value) => value
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String? orderStatusError(
  String current,
  String next, {
  required bool hasReceipt,
}) {
  if (!orderStatuses.contains(next)) return 'Choose a valid order status.';
  if (current == next) return null;
  if (current == 'cancelled' || current == 'completed') {
    return 'This order can no longer be changed.';
  }
  if (next == 'cancelled') {
    return current == 'to_pay'
        ? null
        : 'Only orders that have not reached To Ship can be cancelled.';
  }
  if (orderStatuses.indexOf(next) < orderStatuses.indexOf(current)) {
    return 'An order cannot return to an earlier stage.';
  }
  if (!hasReceipt && (next == 'to_ship' || current == 'to_pay')) {
    return 'A payment receipt is required before shipping.';
  }
  return null;
}

String orderPaymentAfter(String currentPayment, String nextStatus) =>
    nextStatus == 'cancelled'
    ? currentPayment
    : nextStatus == 'to_pay'
    ? 'unpaid'
    : 'paid';
