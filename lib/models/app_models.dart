import 'package:cloud_firestore/cloud_firestore.dart';

import 'store_address.dart';
import 'product_name.dart';
import 'category_label.dart';
import 'store_hours.dart';
import 'shelf_life.dart';
import 'promotion.dart';

DateTime _date(dynamic value, {DateTime? fallback}) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return fallback ?? DateTime.now();
}

int _int(dynamic value) => value is num ? value.round() : 0;

class StoreCategory {
  final String id;
  final String name;
  final bool active;
  final int sortOrder;
  const StoreCategory({
    required this.id,
    required this.name,
    required this.active,
    this.sortOrder = 0,
  });

  static int compare(StoreCategory a, StoreCategory b) {
    final order = a.sortOrder.compareTo(b.sortOrder);
    if (order != 0) return order;
    final name = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return name != 0 ? name : a.id.compareTo(b.id);
  }

  factory StoreCategory.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      StoreCategory(
        id: doc.id,
        name: categoryTitleCase(doc.data()?['name'] as String? ?? doc.id),
        active: doc.data()?['isActive'] == true,
        sortOrder: _int(doc.data()?['sortOrder']),
      );
}

class StoreInfo {
  final String id;
  final String name;
  final String code;
  final String? logoPath;
  final String status;
  final String currency;
  final String shopAddress;
  final StoreAddress? address;
  final DateTime? createdAt;
  final StoreHours operatingHours;

  const StoreInfo({
    required this.id,
    required this.name,
    required this.code,
    this.logoPath,
    this.status = 'active',
    this.currency = 'MYR',
    this.shopAddress = '',
    this.address,
    this.createdAt,
    this.operatingHours = const StoreHours(),
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
      shopAddress: data['shopAddress'] as String? ?? '',
      address: StoreAddress.fromMap(data['address']),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : data['createdAt'] is DateTime
          ? data['createdAt'] as DateTime
          : null,
      operatingHours: StoreHours.fromMap(data['operatingHours']),
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
  final DateTime? receivedAt;
  final int? totalShelfLifeDays;
  final Map<String, dynamic>? promotion;

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
    this.receivedAt,
    this.totalShelfLifeDays,
    this.promotion,
  });

  int get availableQuantity =>
      (quantityOnHand - quantityReserved).clamp(0, quantityOnHand);
  int get sellingPriceCents => promotionEnabled && promotionPriceCents != null
      ? promotionPriceCents!
      : basePriceCents;
  ShelfLifeType get shelfLife => shelfLifeAt(DateTime.now());
  ShelfLifeType shelfLifeAt(DateTime now) => shelfLifeType(
    totalShelfLifeDays ?? calendarDaysBetween(receivedAt ?? now, expiryAt),
  );
  ShelfLifeColour get expiryColour => expiryColourAt(DateTime.now());
  ShelfLifeColour expiryColourAt(DateTime now) =>
      shelfLifeColour(shelfLifeAt(now), daysUntilExpiryFrom(now));
  String get promotionLabel =>
      promotionEnabled ? Promotion.fromMap(promotion).label : '';
  bool get bundlePromotion =>
      promotionEnabled && promotion?['type'] == 'bundle';
  bool canSellAt(DateTime time) =>
      status == 'active' && availableQuantity > 0 && expiryAt.isAfter(time);
  int get daysUntilExpiry => daysUntilExpiryFrom(DateTime.now());

  int daysUntilExpiryFrom(DateTime date) {
    final expiry = expiryAt.toLocal();
    final today = date.toLocal();
    // Compare calendar dates so yesterday cannot round up to zero days.
    return DateTime.utc(
      expiry.year,
      expiry.month,
      expiry.day,
    ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  }

  factory InventoryBatch.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return InventoryBatch(
      id: doc.id,
      productId: data['productId'] as String? ?? '',
      productName: capitalizeProductName(
        data['productName'] as String? ?? 'Unnamed product',
      ),
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
      receivedAt: data['receivedAt'] is Timestamp
          ? (data['receivedAt'] as Timestamp).toDate()
          : data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      totalShelfLifeDays: (data['totalShelfLifeDays'] as num?)?.toInt(),
      promotion: data['promotion'] is Map
          ? Map<String, dynamic>.from(data['promotion'])
          : null,
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
      productName: capitalizeProductName(
        data['productName'] as String? ?? 'Product',
      ),
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
  final String? receiptPath;
  final String? cancellationReason;

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
    this.receiptPath,
    this.cancellationReason,
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
      receiptPath: data['receiptPath'] as String?,
      cancellationReason: data['cancellationReason'] as String?,
    );
  }
}

class OrderLine {
  final String id;
  final String productId;
  final String batchId;
  final String productName;
  final String? imagePath;
  final DateTime expiryAt;
  final String unitLabel;
  final int quantity;
  final int unitPriceCents;
  final int lineTotalCents;
  final String promotionLabel;
  final String categoryId;
  final int? regularUnitPriceCents;
  final DateTime? receivedAt;
  final int? totalShelfLifeDays;

  const OrderLine({
    required this.id,
    this.productId = '',
    this.batchId = '',
    required this.productName,
    this.imagePath,
    required this.expiryAt,
    required this.unitLabel,
    required this.quantity,
    required this.unitPriceCents,
    required this.lineTotalCents,
    this.promotionLabel = '',
    this.categoryId = 'Others',
    this.regularUnitPriceCents,
    this.receivedAt,
    this.totalShelfLifeDays,
  });

  ShelfLifeColour expiryColourAt(DateTime now) => shelfLifeColour(
    shelfLifeType(
      totalShelfLifeDays ??
          (receivedAt == null ? 0 : calendarDaysBetween(receivedAt!, expiryAt)),
    ),
    calendarDaysBetween(now, expiryAt),
  );

  factory OrderLine.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return OrderLine.fromData(doc.id, doc.data() ?? const <String, dynamic>{});
  }

  factory OrderLine.fromData(String id, Map<String, dynamic> data) {
    return OrderLine(
      id: id,
      productId: data['productId'] as String? ?? '',
      batchId: data['batchId'] as String? ?? '',
      productName: capitalizeProductName(
        data['productName'] as String? ?? 'Product',
      ),
      imagePath: data['imagePath'] as String?,
      expiryAt: _date(data['expiryAt']),
      unitLabel: data['unitLabel'] as String? ?? 'unit',
      quantity: _int(data['quantity']),
      unitPriceCents: _int(data['unitPriceCents']),
      lineTotalCents: _int(data['lineTotalCents']),
      promotionLabel: data['promotionLabel'] as String? ?? '',
      categoryId: data['categoryId'] as String? ?? 'Others',
      regularUnitPriceCents: (data['regularUnitPriceCents'] as num?)?.toInt(),
      receivedAt: data['receivedAt'] == null ? null : _date(data['receivedAt']),
      totalShelfLifeDays: (data['totalShelfLifeDays'] as num?)?.toInt(),
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
      productName: capitalizeProductName(
        data['productName'] as String? ?? 'Product',
      ),
      categoryId: data['categoryId'] as String? ?? 'others',
      eventType: data['eventType'] as String? ?? 'adjusted',
      quantity: _int(data['quantity']),
      occurredAt: _date(data['occurredAt']),
    );
  }
}
