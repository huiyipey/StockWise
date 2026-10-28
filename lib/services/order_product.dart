import '../models/app_models.dart';

InventoryBatch? sellingOrderProduct(
  OrderLine line,
  Iterable<InventoryBatch> inventory,
  DateTime now,
) {
  final matches = inventory.where((item) {
    final sameProduct = line.productId.isNotEmpty
        ? item.productId == line.productId
        : line.batchId.isNotEmpty && item.id == line.batchId;
    return sameProduct && item.canSellAt(now);
  }).toList();
  matches.sort((a, b) {
    if (a.id == line.batchId && b.id != line.batchId) return -1;
    if (b.id == line.batchId && a.id != line.batchId) return 1;
    final expiry = a.expiryAt.compareTo(b.expiryAt);
    return expiry != 0 ? expiry : a.id.compareTo(b.id);
  });
  return matches.isEmpty ? null : matches.first;
}
