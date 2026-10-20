import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_models.dart';
import 'store_session.dart';

class FirestoreService {
  FirestoreService._();

  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User get _user {
    final user = _auth.currentUser;
    if (user == null) throw StateError('You must be signed in.');
    return user;
  }

  String get _storeId {
    final storeId = StoreSession.instance.storeId;
    if (storeId == null) throw StateError('Select a store first.');
    return storeId;
  }

  DocumentReference<Map<String, dynamic>> get _storeRef =>
      _db.collection('stores').doc(_storeId);

  Future<void> ensureUserProfile() async {
    final user = _user;
    final userRef = _db.collection('users').doc(user.uid);
    final existing = await userRef.get();
    final profile = <String, dynamic>{
      'email': user.email,
      'displayName': user.displayName ?? _nameFromEmail(user.email),
      'photoPath': user.photoURL,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!existing.exists) {
      profile.addAll({
        'preferences': {
          'expiryAlerts': true,
          'orderUpdates': true,
          'promotions': true,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await userRef.set(profile, SetOptions(merge: true));
  }

  String _nameFromEmail(String? email) {
    final local = (email ?? 'StockWise User').split('@').first;
    return local
        .split(RegExp(r'[._-]'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  Stream<List<StoreInfo>> watchStores() => _db
      .collection('stores')
      .where('status', isEqualTo: 'active')
      .snapshots()
      .map((snapshot) {
        final stores = snapshot.docs.map(StoreInfo.fromDoc).toList();
        stores.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        return stores;
      });

  Stream<List<StoreMembership>> watchMyMemberships() => _db
      .collectionGroup('members')
      .where('userId', isEqualTo: _user.uid)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(StoreMembership.fromDoc)
            .where((membership) => membership.isActive)
            .toList(),
      );

  Future<StoreInfo> createStore({required String name}) async {
    final trimmed = name.trim();
    if (trimmed.length < 2) throw ArgumentError('Enter a valid store name.');
    final user = _user;
    final storeRef = _db.collection('stores').doc();
    final batch = _db.batch();
    final code = trimmed
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase()
        .padRight(4, 'X')
        .substring(0, 4);

    batch.set(storeRef, {
      'name': trimmed,
      'nameLowercase': trimmed.toLowerCase(),
      'code': '$code-${storeRef.id.substring(0, 4).toUpperCase()}',
      'ownerUid': user.uid,
      'email': user.email,
      'timezone': 'Asia/Kuala_Lumpur',
      'currency': 'MYR',
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(storeRef.collection('members').doc(user.uid), {
      'storeId': storeRef.id,
      'userId': user.uid,
      'role': 'owner',
      'isActive': true,
      'joinedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    for (final category in const [
      'Dairy',
      'Bakery',
      'Vegetables',
      'Fruits',
      'Meat',
      'Household',
      'Others',
    ]) {
      final id = category.toLowerCase();
      batch.set(storeRef.collection('categories').doc(id), {
        'storeId': storeRef.id,
        'name': category,
        'slug': id,
        'sortOrder': 0,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    batch.set(storeRef.collection('settings').doc('inventory'), {
      'storeId': storeRef.id,
      'expiryWarningDays': [2, 3, 7],
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(storeRef.collection('settings').doc('commerce'), {
      'storeId': storeRef.id,
      'currency': 'MYR',
      'deliveryFeeCents': 500,
      'minimumOrderCents': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_db.collection('users').doc(user.uid), {
      'activeStoreId': storeRef.id,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
    return StoreInfo(
      id: storeRef.id,
      name: trimmed,
      code: '$code-${storeRef.id.substring(0, 4).toUpperCase()}',
    );
  }

  Future<void> saveActiveStore(String storeId) =>
      _db.collection('users').doc(_user.uid).set({
        'activeStoreId': storeId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Stream<List<String>> watchCategories() => _storeRef
      .collection('categories')
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((snapshot) {
        final names = snapshot.docs
            .map((doc) => doc.data()['name'] as String? ?? doc.id)
            .toList();
        names.sort();
        return names;
      });

  Stream<List<InventoryBatch>> watchInventory() => _storeRef
      .collection('inventoryBatches')
      .orderBy('expiryAt')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(InventoryBatch.fromDoc).toList());

  Stream<List<InventoryBatch>> watchPromotions() => watchInventory().map(
    (items) => items
        .where(
          (item) =>
              item.status == 'active' &&
              item.availableQuantity > 0 &&
              item.promotionEnabled &&
              item.expiryAt.isAfter(DateTime.now()),
        )
        .toList(),
  );

  Future<String?> uploadProductImage(XFile? file, String productId) async {
    if (file == null) return null;
    final Uint8List bytes = await file.readAsBytes();
    final extension = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : 'jpg';
    final ref = _storage.ref(
      'stores/$_storeId/product-images/$productId/main.$extension',
    );
    await ref.putData(
      bytes,
      SettableMetadata(contentType: file.mimeType ?? 'image/jpeg'),
    );
    return ref.fullPath;
  }

  Future<void> saveInventoryItem({
    InventoryBatch? existing,
    required String name,
    required String category,
    required String unitLabel,
    String? barcode,
    required DateTime expiryAt,
    required int quantity,
    required int basePriceCents,
    required bool promotionEnabled,
    int? promotionPriceCents,
    required bool notifyOnExpiry,
    XFile? image,
  }) async {
    if (name.trim().isEmpty) throw ArgumentError('Product name is required.');
    if (quantity < 0) throw ArgumentError('Quantity cannot be negative.');
    if (basePriceCents < 0) throw ArgumentError('Price cannot be negative.');
    if (promotionEnabled &&
        (promotionPriceCents == null || promotionPriceCents < 0)) {
      throw ArgumentError('Enter a valid promotion price.');
    }

    final productRef = existing == null
        ? _storeRef.collection('products').doc()
        : _storeRef.collection('products').doc(existing.productId);
    final batchRef = existing == null
        ? _storeRef.collection('inventoryBatches').doc()
        : _storeRef.collection('inventoryBatches').doc(existing.id);
    final uploadedPath = await uploadProductImage(image, productRef.id);
    final imagePath = uploadedPath ?? existing?.imagePath;
    final categoryId = category.toLowerCase().replaceAll(' ', '-');
    final write = _db.batch();
    final productData = <String, dynamic>{
      'storeId': _storeId,
      'name': name.trim(),
      'nameLowercase': name.trim().toLowerCase(),
      'categoryId': categoryId,
      'barcode': barcode?.trim().isEmpty == true ? null : barcode?.trim(),
      'imagePath': imagePath,
      'unitLabel': unitLabel.trim().isEmpty ? 'unit' : unitLabel.trim(),
      'basePriceCents': basePriceCents,
      'currency': 'MYR',
      'isActive': true,
      'createdBy': _user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final inventoryData = <String, dynamic>{
      'storeId': _storeId,
      'productId': productRef.id,
      'productName': name.trim(),
      'productNameLowercase': name.trim().toLowerCase(),
      'categoryId': categoryId,
      'barcode': barcode?.trim().isEmpty == true ? null : barcode?.trim(),
      'imagePath': imagePath,
      'unitLabel': unitLabel.trim().isEmpty ? 'unit' : unitLabel.trim(),
      'expiryAt': Timestamp.fromDate(expiryAt),
      'quantityOnHand': quantity,
      'quantityReserved': existing?.quantityReserved ?? 0,
      'basePriceCents': basePriceCents,
      'promotionEnabled': promotionEnabled,
      'promotionPriceCents': promotionEnabled ? promotionPriceCents : null,
      'notifyOnExpiry': notifyOnExpiry,
      'status': quantity == 0 ? 'depleted' : 'active',
      'createdBy': _user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (existing == null) {
      productData['createdAt'] = FieldValue.serverTimestamp();
      inventoryData['createdAt'] = FieldValue.serverTimestamp();
    }
    write.set(productRef, productData, SetOptions(merge: true));
    write.set(batchRef, inventoryData, SetOptions(merge: true));
    if (existing == null) {
      write.set(_storeRef.collection('inventoryEvents').doc(), {
        'storeId': _storeId,
        'batchId': batchRef.id,
        'productId': productRef.id,
        'productName': name.trim(),
        'categoryId': categoryId,
        'eventType': 'received',
        'quantity': quantity,
        'quantityDelta': quantity,
        'actorUid': _user.uid,
        'occurredAt': FieldValue.serverTimestamp(),
      });
    } else if (quantity != existing.quantityOnHand) {
      write.set(_storeRef.collection('inventoryEvents').doc(), {
        'storeId': _storeId,
        'batchId': batchRef.id,
        'productId': productRef.id,
        'productName': name.trim(),
        'categoryId': categoryId,
        'eventType': 'adjusted',
        'quantity': (quantity - existing.quantityOnHand).abs(),
        'quantityDelta': quantity - existing.quantityOnHand,
        'actorUid': _user.uid,
        'occurredAt': FieldValue.serverTimestamp(),
      });
    }
    await write.commit();
  }

  Future<void> consumeBatch(InventoryBatch batch, {int quantity = 1}) =>
      _reduceBatch(batch, quantity: quantity, eventType: 'consumed');

  Future<void> discardBatch(
    InventoryBatch batch, {
    required int quantity,
    String reason = 'discarded',
  }) => _reduceBatch(
    batch,
    quantity: quantity,
    eventType: 'discarded',
    reason: reason,
  );

  Future<void> _reduceBatch(
    InventoryBatch batch, {
    required int quantity,
    required String eventType,
    String? reason,
  }) async {
    if (quantity <= 0) throw ArgumentError('Quantity must be positive.');
    final ref = _storeRef.collection('inventoryBatches').doc(batch.id);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final current = InventoryBatch.fromDoc(snapshot);
      if (current.quantityOnHand < quantity) {
        throw StateError('Not enough stock available.');
      }
      final remaining = current.quantityOnHand - quantity;
      transaction.update(ref, {
        'quantityOnHand': remaining,
        'status': remaining == 0 ? 'depleted' : 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(_storeRef.collection('inventoryEvents').doc(), {
        'storeId': _storeId,
        'batchId': current.id,
        'productId': current.productId,
        'productName': current.productName,
        'categoryId': current.categoryId,
        'eventType': eventType,
        'quantity': quantity,
        'quantityDelta': -quantity,
        'reason': reason,
        'actorUid': _user.uid,
        'occurredAt': FieldValue.serverTimestamp(),
      });
    });
    await _createNotification(
      recipientUid: _user.uid,
      type: 'stock_consumed',
      title: '${batch.productName} updated',
      body:
          '$quantity ${batch.unitLabel}${quantity == 1 ? '' : 's'} marked as $eventType.',
      relatedCollection: 'inventoryBatches',
      relatedDocumentId: batch.id,
    );
  }

  Stream<List<CartLine>> watchCart() => _storeRef
      .collection('carts')
      .doc(_user.uid)
      .collection('items')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(CartLine.fromDoc).toList());

  Future<void> addToCart(InventoryBatch batch) async {
    if (batch.availableQuantity <= 0) {
      throw StateError('This item is out of stock.');
    }
    final cartRef = _storeRef.collection('carts').doc(_user.uid);
    final itemRef = cartRef.collection('items').doc(batch.id);
    await _db.runTransaction((transaction) async {
      final batchSnap = await transaction.get(
        _storeRef.collection('inventoryBatches').doc(batch.id),
      );
      final currentBatch = InventoryBatch.fromDoc(batchSnap);
      final itemSnap = await transaction.get(itemRef);
      final currentQuantity = itemSnap.exists
          ? (itemSnap.data()?['quantity'] as num? ?? 0).round()
          : 0;
      if (currentQuantity + 1 > currentBatch.availableQuantity) {
        throw StateError('Only ${currentBatch.availableQuantity} available.');
      }
      transaction.set(cartRef, {
        'storeId': _storeId,
        'ownerUid': _user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      final itemData = <String, dynamic>{
        'storeId': _storeId,
        'batchId': batch.id,
        'productId': batch.productId,
        'productName': batch.productName,
        'imagePath': batch.imagePath,
        'expiryAt': Timestamp.fromDate(batch.expiryAt),
        'quantity': currentQuantity + 1,
        'unitPriceCents': batch.sellingPriceCents,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (!itemSnap.exists) {
        itemData['addedAt'] = FieldValue.serverTimestamp();
      }
      transaction.set(itemRef, itemData, SetOptions(merge: true));
    });
  }

  Future<void> updateCartQuantity(CartLine line, int quantity) async {
    final ref = _storeRef
        .collection('carts')
        .doc(_user.uid)
        .collection('items')
        .doc(line.id);
    if (quantity <= 0) {
      await ref.delete();
      return;
    }
    final batch = await _storeRef
        .collection('inventoryBatches')
        .doc(line.batchId)
        .get();
    final available = InventoryBatch.fromDoc(batch).availableQuantity;
    if (quantity > available) throw StateError('Only $available available.');
    await ref.update({
      'quantity': quantity,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeCartItem(String id) => _storeRef
      .collection('carts')
      .doc(_user.uid)
      .collection('items')
      .doc(id)
      .delete();

  Future<String> placeOrder({
    required String fulfillmentType,
    required Map<String, dynamic> receiver,
    required String paymentMethod,
  }) async {
    final cartItemsRef = _storeRef
        .collection('carts')
        .doc(_user.uid)
        .collection('items');
    final cartSnapshot = await cartItemsRef.get();
    if (cartSnapshot.docs.isEmpty) throw StateError('Your cart is empty.');
    final cartLines = cartSnapshot.docs.map(CartLine.fromDoc).toList();
    final settings = await _storeRef
        .collection('settings')
        .doc('commerce')
        .get();
    final deliveryFee = fulfillmentType == 'delivery'
        ? ((settings.data()?['deliveryFeeCents'] as num?)?.round() ?? 500)
        : 0;
    final subtotal = cartLines.fold<int>(
      0,
      (total, line) => total + line.lineTotalCents,
    );
    final orderRef = _storeRef.collection('orders').doc();
    final orderNumber =
        'SW-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';

    await _db.runTransaction((transaction) async {
      for (final line in cartLines) {
        final batchRef = _storeRef
            .collection('inventoryBatches')
            .doc(line.batchId);
        final batchSnap = await transaction.get(batchRef);
        if (!batchSnap.exists) {
          throw StateError('${line.productName} is no longer available.');
        }
        final batch = InventoryBatch.fromDoc(batchSnap);
        if (batch.availableQuantity < line.quantity) {
          throw StateError(
            'Only ${batch.availableQuantity} ${line.productName} available.',
          );
        }
        final remaining = batch.quantityOnHand - line.quantity;
        transaction.update(batchRef, {
          'quantityOnHand': remaining,
          'status': remaining == 0 ? 'depleted' : 'active',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(orderRef.collection('items').doc(), {
          'storeId': _storeId,
          'productId': line.productId,
          'batchId': line.batchId,
          'productName': line.productName,
          'imagePath': line.imagePath,
          'expiryAt': Timestamp.fromDate(line.expiryAt),
          'unitLabel': batch.unitLabel,
          'quantity': line.quantity,
          'unitPriceCents': line.unitPriceCents,
          'lineTotalCents': line.lineTotalCents,
        });
        transaction.set(_storeRef.collection('inventoryEvents').doc(), {
          'storeId': _storeId,
          'batchId': line.batchId,
          'productId': line.productId,
          'productName': line.productName,
          'categoryId': batch.categoryId,
          'eventType': 'sold',
          'quantity': line.quantity,
          'quantityDelta': -line.quantity,
          'actorUid': _user.uid,
          'orderId': orderRef.id,
          'occurredAt': FieldValue.serverTimestamp(),
        });
        transaction.delete(cartItemsRef.doc(line.id));
      }
      transaction.set(orderRef, {
        'storeId': _storeId,
        'orderNumber': orderNumber,
        'userId': _user.uid,
        'status': 'to_pay',
        'paymentStatus': 'unpaid',
        'fulfillmentType': fulfillmentType,
        'receiver': receiver,
        'payment': {'methodLabel': paymentMethod},
        'subtotalCents': subtotal,
        'shippingFeeCents': deliveryFee,
        'totalCents': subtotal + deliveryFee,
        'currency': 'MYR',
        'placedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    await _createNotification(
      recipientUid: _user.uid,
      type: 'order_status',
      title: 'Order $orderNumber placed',
      body: 'Your order is waiting for payment.',
      relatedCollection: 'orders',
      relatedDocumentId: orderRef.id,
    );
    return orderRef.id;
  }

  Stream<List<StoreOrder>> watchOrders({required bool admin}) {
    Query<Map<String, dynamic>> query = _storeRef.collection('orders');
    if (!admin) query = query.where('userId', isEqualTo: _user.uid);
    return query.snapshots().map((snapshot) {
      final orders = snapshot.docs.map(StoreOrder.fromDoc).toList();
      orders.sort((a, b) => b.placedAt.compareTo(a.placedAt));
      return orders;
    });
  }

  Stream<List<OrderLine>> watchOrderLines(String orderId) => _storeRef
      .collection('orders')
      .doc(orderId)
      .collection('items')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(OrderLine.fromDoc).toList());

  Future<void> updateOrderStatus(StoreOrder order, String status) async {
    final paid = status == 'to_pay' ? 'unpaid' : 'paid';
    await _storeRef.collection('orders').doc(order.id).update({
      'status': status,
      'paymentStatus': paid,
      'updatedAt': FieldValue.serverTimestamp(),
      if (status == 'completed') 'completedAt': FieldValue.serverTimestamp(),
    });
    await _createNotification(
      recipientUid: order.userId,
      type: 'order_status',
      title: 'Order ${order.orderNumber} updated',
      body: 'Status: ${status.replaceAll('_', ' ')}.',
      relatedCollection: 'orders',
      relatedDocumentId: order.id,
    );
  }

  Stream<List<AppNotification>> watchNotifications() => _storeRef
      .collection('notifications')
      .where('recipientUid', isEqualTo: _user.uid)
      .snapshots()
      .map((snapshot) {
        final notices = snapshot.docs.map(AppNotification.fromDoc).toList();
        notices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return notices;
      });

  Future<void> markNotificationRead(String id) => _storeRef
      .collection('notifications')
      .doc(id)
      .update({'readAt': FieldValue.serverTimestamp()});

  Future<void> _createNotification({
    required String recipientUid,
    required String type,
    required String title,
    required String body,
    String? relatedCollection,
    String? relatedDocumentId,
  }) => _storeRef.collection('notifications').add({
    'storeId': _storeId,
    'recipientUid': recipientUid,
    'type': type,
    'title': title,
    'body': body,
    'relatedCollection': relatedCollection,
    'relatedDocumentId': relatedDocumentId,
    'readAt': null,
    'createdAt': FieldValue.serverTimestamp(),
  });

  Stream<List<InventoryEvent>> watchWasteEvents() =>
      _storeRef.collection('inventoryEvents').snapshots().map((snapshot) {
        final events = snapshot.docs
            .map(InventoryEvent.fromDoc)
            .where(
              (event) =>
                  const {'expired', 'discarded'}.contains(event.eventType),
            )
            .toList();
        events.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
        return events;
      });

  Stream<Map<String, dynamic>> watchUserProfile() => _db
      .collection('users')
      .doc(_user.uid)
      .snapshots()
      .map((doc) => doc.data() ?? const <String, dynamic>{});

  Future<void> updateNotificationPreference(bool enabled) =>
      _db.collection('users').doc(_user.uid).set({
        'preferences': {
          'expiryAlerts': enabled,
          'orderUpdates': enabled,
          'promotions': enabled,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Future<String?> imageUrl(String? path) async {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    try {
      return await _storage.ref(path).getDownloadURL();
    } on FirebaseException {
      return null;
    }
  }
}
