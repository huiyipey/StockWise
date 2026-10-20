import 'package:cloud_firestore/cloud_firestore.dart';

DateTime _date(dynamic value, {DateTime? fallback}) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return fallback ?? DateTime.now();
}

int _int(dynamic value) => value is num ? value.round() : 0;

class StoreInfo {
  final String id;
  final String name;
  final String code;
  final String? logoPath;
  final String status;
  final String currency;

  const StoreInfo({
    required this.id,
    required this.name,
    required this.code,
    this.logoPath,
    this.status = 'active',
    this.currency = 'MYR',
  });

  factory StoreInfo.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return StoreInfo(
      id: doc.id,
      name: data['name'] as String? ?? 'Unnamed store',
      code:
          data['code'] as String? ??
          doc.id.substring(0, doc.id.length.clamp(0, 6)).toUpperCase(),
      logoPath: data['logoPath'] as String?,
      status: data['status'] as String? ?? 'active',
      currency: data['currency'] as String? ?? 'MYR',
    );
  }
}

class StoreMembership {
  final String storeId;
  final String userId;
  final String role;
  final bool isActive;

  const StoreMembership({
    required this.storeId,
    required this.userId,
    required this.role,
    required this.isActive,
  });

  factory StoreMembership.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return StoreMembership(
      storeId:
          data['storeId'] as String? ?? doc.reference.parent.parent?.id ?? '',
      userId: data['userId'] as String? ?? doc.id,
      role: data['role'] as String? ?? 'staff',
      isActive: data['isActive'] as bool? ?? true,
    );
  }
}

class InventoryBatch {
  final String id;
  final String productId;
  final String productName;
  final String categoryId;
  final String? barcode;
  final String? imagePath;
  final String unitLabel;
  final DateTime expiryAt;
  final int quantityOnHand;
  final int quantityReserved;
  final int basePriceCents;
  final bool promotionEnabled;
  final int? promotionPriceCents;
  final bool notifyOnExpiry;
  final String status;

  const InventoryBatch({
    required this.id,
    required this.productId,
    required this.productName,
    required this.categoryId,
    this.barcode,
    this.imagePath,
    required this.unitLabel,
    required this.expiryAt,
    required this.quantityOnHand,
    required this.quantityReserved,
    required this.basePriceCents,
    required this.promotionEnabled,
    this.promotionPriceCents,
    required this.notifyOnExpiry,
    required this.status,
  });

  int get availableQuantity =>
      (quantityOnHand - quantityReserved).clamp(0, quantityOnHand);
  int get sellingPriceCents => promotionEnabled && promotionPriceCents != null
      ? promotionPriceCents!
      : basePriceCents;
  int get daysUntilExpiry => expiryAt.difference(DateTime.now()).inDays;

  factory InventoryBatch.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return InventoryBatch(
      id: doc.id,
      productId: data['productId'] as String? ?? '',
      productName: data['productName'] as String? ?? 'Unnamed product',
      categoryId: data['categoryId'] as String? ?? 'others',
      barcode: data['barcode'] as String?,
      imagePath: data['imagePath'] as String?,
      unitLabel: data['unitLabel'] as String? ?? 'unit',
      expiryAt: _date(data['expiryAt']),
      quantityOnHand: _int(data['quantityOnHand']),
      quantityReserved: _int(data['quantityReserved']),
      basePriceCents: _int(data['basePriceCents']),
      promotionEnabled: data['promotionEnabled'] as bool? ?? false,
      promotionPriceCents: data['promotionPriceCents'] == null
          ? null
          : _int(data['promotionPriceCents']),
      notifyOnExpiry: data['notifyOnExpiry'] as bool? ?? true,
      status: data['status'] as String? ?? 'active',
    );
  }
}

class CartLine {
  final String id;
  final String batchId;
  final String productId;
  final String productName;
  final String? imagePath;
  final DateTime expiryAt;
  final int quantity;
  final int unitPriceCents;

  const CartLine({
    required this.id,
    required this.batchId,
    required this.productId,
    required this.productName,
    this.imagePath,
    required this.expiryAt,
    required this.quantity,
    required this.unitPriceCents,
  });

  int get lineTotalCents => quantity * unitPriceCents;

  factory CartLine.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CartLine(
      id: doc.id,
      batchId: data['batchId'] as String? ?? doc.id,
      productId: data['productId'] as String? ?? '',
      productName: data['productName'] as String? ?? 'Product',
      imagePath: data['imagePath'] as String?,
      expiryAt: _date(data['expiryAt']),
      quantity: _int(data['quantity']),
      unitPriceCents: _int(data['unitPriceCents']),
    );
  }
}

class StoreOrder {
  final String id;
  final String orderNumber;
  final String userId;
  final String status;
  final String paymentStatus;
  final String fulfillmentType;
  final Map<String, dynamic> receiver;
  final Map<String, dynamic> payment;
  final int subtotalCents;
  final int shippingFeeCents;
  final int totalCents;
  final DateTime placedAt;

  const StoreOrder({
    required this.id,
    required this.orderNumber,
    required this.userId,
    required this.status,
    required this.paymentStatus,
    required this.fulfillmentType,
    required this.receiver,
    required this.payment,
    required this.subtotalCents,
    required this.shippingFeeCents,
    required this.totalCents,
    required this.placedAt,
  });

  factory StoreOrder.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return StoreOrder(
      id: doc.id,
      orderNumber: data['orderNumber'] as String? ?? doc.id,
      userId: data['userId'] as String? ?? '',
      status: data['status'] as String? ?? 'to_pay',
      paymentStatus: data['paymentStatus'] as String? ?? 'unpaid',
      fulfillmentType: data['fulfillmentType'] as String? ?? 'pickup',
      receiver: Map<String, dynamic>.from(data['receiver'] as Map? ?? const {}),
      payment: Map<String, dynamic>.from(data['payment'] as Map? ?? const {}),
      subtotalCents: _int(data['subtotalCents']),
      shippingFeeCents: _int(data['shippingFeeCents']),
      totalCents: _int(data['totalCents']),
      placedAt: _date(data['placedAt']),
    );
  }
}

class OrderLine {
  final String id;
  final String productName;
  final String? imagePath;
  final DateTime expiryAt;
  final String unitLabel;
  final int quantity;
  final int unitPriceCents;
  final int lineTotalCents;

  const OrderLine({
    required this.id,
    required this.productName,
    this.imagePath,
    required this.expiryAt,
    required this.unitLabel,
    required this.quantity,
    required this.unitPriceCents,
    required this.lineTotalCents,
  });

  factory OrderLine.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return OrderLine(
      id: doc.id,
      productName: data['productName'] as String? ?? 'Product',
      imagePath: data['imagePath'] as String?,
      expiryAt: _date(data['expiryAt']),
      unitLabel: data['unitLabel'] as String? ?? 'unit',
      quantity: _int(data['quantity']),
      unitPriceCents: _int(data['unitPriceCents']),
      lineTotalCents: _int(data['lineTotalCents']),
    );
  }
}

class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AppNotification(
      id: doc.id,
      type: data['type'] as String? ?? 'info',
      title: data['title'] as String? ?? 'StockWise',
      body: data['body'] as String? ?? '',
      createdAt: _date(data['createdAt']),
      readAt: data['readAt'] == null ? null : _date(data['readAt']),
    );
  }
}

class InventoryEvent {
  final String id;
  final String productName;
  final String categoryId;
  final String eventType;
  final int quantity;
  final DateTime occurredAt;

  const InventoryEvent({
    required this.id,
    required this.productName,
    required this.categoryId,
    required this.eventType,
    required this.quantity,
    required this.occurredAt,
  });

  factory InventoryEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return InventoryEvent(
      id: doc.id,
      productName: data['productName'] as String? ?? 'Product',
      categoryId: data['categoryId'] as String? ?? 'others',
      eventType: data['eventType'] as String? ?? 'adjusted',
      quantity: _int(data['quantity']),
      occurredAt: _date(data['occurredAt']),
    );
  }
}
