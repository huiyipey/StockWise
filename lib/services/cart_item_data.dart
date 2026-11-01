/// Cart writes use the current database values, not formatted display models.
/// Firestore validates the stored product name and price against this batch.
Map<String, dynamic> cartItemData({
  required String storeId,
  required String batchId,
  required Map<String, dynamic> batch,
  required int quantity,
}) => {
  'storeId': storeId,
  'batchId': batchId,
  'productId': batch['productId'],
  'productName': batch['productName'],
  'imagePath': batch['imagePath'],
  'expiryAt': batch['expiryAt'],
  'quantity': quantity,
  'unitPriceCents':
      batch['promotionEnabled'] == true && batch['promotionPriceCents'] != null
      ? batch['promotionPriceCents']
      : batch['basePriceCents'],
};
