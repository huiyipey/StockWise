import '../models/app_models.dart';

String? cartUnavailableReason(
  CartLine line,
  InventoryBatch? item,
  DateTime now,
) {
  if (item == null ||
      item.productId != line.productId ||
      item.status != 'active') {
    return 'No longer selling';
  }
  if (!item.expiryAt.isAfter(now)) return 'Expired';
  if (item.availableQuantity <= 0) return 'Out of stock';
  if (item.availableQuantity < line.quantity) {
    return 'Only ${item.availableQuantity} available';
  }
  return null;
}
