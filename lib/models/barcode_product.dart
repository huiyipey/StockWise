import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import 'app_models.dart';
import 'product_name.dart';

/// Reusable product details, without batch expiry, stock or promotions.
class BarcodeProduct {
  final String id;
  final String storeId;
  final String name;
  final String barcode;
  final String categoryId;
  final String unitLabel;
  final int basePriceCents;
  final String? imagePath;
  final DateTime? updatedAt;

  const BarcodeProduct({
    required this.id,
    required this.storeId,
    required this.name,
    required this.barcode,
    required this.categoryId,
    required this.unitLabel,
    required this.basePriceCents,
    this.imagePath,
    this.updatedAt,
  });

  factory BarcodeProduct.fromData(
    String id,
    String storeId,
    Map<String, dynamic> data,
  ) => BarcodeProduct(
    id: id,
    storeId: storeId,
    name: capitalizeProductName(data['name'] as String? ?? ''),
    barcode: data['barcode'] as String? ?? '',
    categoryId: data['categoryId'] as String? ?? '',
    unitLabel: data['unitLabel'] as String? ?? 'unit',
    basePriceCents: (data['basePriceCents'] as num? ?? 0).round(),
    imagePath: data['imagePath'] as String?,
    updatedAt: data['updatedAt'] is Timestamp
        ? (data['updatedAt'] as Timestamp).toDate()
        : null,
  );
}

// Older app versions created another product record for every received batch.
// Prefer the most recently saved details when that barcode has duplicates.
BarcodeProduct? latestBarcodeProduct(Iterable<BarcodeProduct> products) {
  final rows = products
      .where((product) => product.name.trim().isNotEmpty)
      .toList();
  rows.sort((a, b) {
    final time = (b.updatedAt ?? DateTime(1970)).compareTo(
      a.updatedAt ?? DateTime(1970),
    );
    return time != 0 ? time : a.id.compareTo(b.id);
  });
  return rows.isEmpty ? null : rows.first;
}

typedef BarcodeProductLookup = Future<BarcodeProduct?> Function(String barcode);
typedef InventoryItemSaver = Future<void> Function(InventoryItemInput input);

class InventoryItemInput {
  final InventoryBatch? existing;
  final BarcodeProduct? reusedProduct;
  final String name;
  final String category;
  final String unitLabel;
  final String barcode;
  final DateTime expiryAt;
  final int quantity;
  final int basePriceCents;
  final bool promotionEnabled;
  final int? promotionPriceCents;
  final bool notifyOnExpiry;
  final XFile? image;

  const InventoryItemInput({
    this.existing,
    this.reusedProduct,
    required this.name,
    required this.category,
    required this.unitLabel,
    required this.barcode,
    required this.expiryAt,
    required this.quantity,
    required this.basePriceCents,
    required this.promotionEnabled,
    this.promotionPriceCents,
    required this.notifyOnExpiry,
    this.image,
  });
}
