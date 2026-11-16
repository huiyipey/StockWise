import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/app_models.dart';

// Identify stock that can share one received inventory record.
class InventoryReceiptIdentity {
  InventoryReceiptIdentity({
    required String name,
    required String categoryId,
    required String unitLabel,
    required String? barcode,
    required int basePriceCents,
    required DateTime expiryAt,
  }) : _values = [
         _normalized(name),
         categoryId,
         _normalized(unitLabel.trim().isEmpty ? 'unit' : unitLabel),
         barcode?.trim() ?? '',
         basePriceCents,
         _calendarDate(expiryAt),
       ];

  final List<Object> _values;

  // Share a stable transaction target across simultaneous receipts.
  String get documentId =>
      'received-${sha256.convert(utf8.encode(jsonEncode(_values)))}';

  // Ignore presentation casing while preserving barcode leading zeroes.
  static String _normalized(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  static String _calendarDate(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month}-${local.day}';
  }

  // Recheck legacy records inside the transaction before receiving stock.
  bool matches(InventoryBatch batch, DateTime now) {
    if (!['active', 'depleted'].contains(batch.status) ||
        !batch.expiryAt.isAfter(now)) {
      return false;
    }
    final other = InventoryReceiptIdentity(
      name: batch.productName,
      categoryId: batch.categoryId,
      unitLabel: batch.unitLabel,
      barcode: batch.barcode,
      basePriceCents: batch.basePriceCents,
      expiryAt: batch.expiryAt,
    );
    return jsonEncode(_values) == jsonEncode(other._values);
  }
}
