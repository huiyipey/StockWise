import '../models/app_models.dart';

bool matchesInventorySearch(InventoryBatch item, String query) {
  final search = query.trim().toLowerCase();
  return item.productName.toLowerCase().contains(search) ||
      (item.barcode?.toLowerCase().contains(search) ?? false);
}

int compareAdminInventory(
  InventoryBatch a,
  InventoryBatch b, {
  required bool ascending,
  required DateTime today,
}) {
  final aExpired = a.daysUntilExpiryFrom(today) < 0;
  final bExpired = b.daysUntilExpiryFrom(today) < 0;
  if (aExpired != bExpired) return aExpired ? 1 : -1;
  final dates = ascending
      ? a.expiryAt.compareTo(b.expiryAt)
      : b.expiryAt.compareTo(a.expiryAt);
  return dates != 0 ? dates : a.id.compareTo(b.id);
}
