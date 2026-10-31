import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_models.dart';
import '../models/store_address.dart';
import '../models/barcode_product.dart';
import '../models/product_name.dart';
import '../models/category_label.dart';
import 'profile_fields.dart';
import 'store_fields.dart';
import 'order_product.dart';
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
      'emailLowercase': user.email?.trim().toLowerCase(),
      'displayName':
          existing.data()?['displayName'] as String? ??
          user.displayName ??
          _nameFromEmail(user.email),
      'photoPath': existing.data()?['photoPath'] as String? ?? user.photoURL,
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
    final emailLowercase = user.email?.trim().toLowerCase();
    if (user.emailVerified &&
        emailLowercase != null &&
        emailLowercase.isNotEmpty) {
      await _acceptAdminInvitations(emailLowercase);
    }
  }

  Future<void> _acceptAdminInvitations(String emailLowercase) async {
    final invitations = await _db
        .collectionGroup('adminInvites')
        .where('emailLowercase', isEqualTo: emailLowercase)
        .get();
    for (final invitation in invitations.docs) {
      if (invitation.data()['status'] != 'pending') continue;
      final storeRef = invitation.reference.parent.parent;
      if (storeRef == null) continue;
      final memberRef = storeRef.collection('members').doc(_user.uid);
      await _db.runTransaction((transaction) async {
        final currentInvite = await transaction.get(invitation.reference);
        final currentMember = await transaction.get(memberRef);
        if (!currentInvite.exists ||
            currentInvite.data()?['status'] != 'pending') {
          return;
        }
        if (currentMember.exists && currentMember.data()?['role'] == 'owner') {
          return;
        }
        transaction.set(memberRef, {
          'storeId': storeRef.id,
          'userId': _user.uid,
          'email': _user.email,
          'role': 'admin',
          'isActive': true,
          'invitationId': invitation.id,
          'joinedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.update(invitation.reference, {
          'status': 'accepted',
          'acceptedBy': _user.uid,
          'acceptedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    }
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

  Stream<StoreInfo?> watchSelectedStore() => _storeRef.snapshots().map(
    (snapshot) => snapshot.exists ? StoreInfo.fromDoc(snapshot) : null,
  );

  Future<StoreInfo> updateStore({
    required String storeId,
    required String name,
    required StoreAddress address,
  }) async {
    final validation =
        storeNameError(name) ?? shopAddressError(address.formatted);
    if (validation != null) throw ArgumentError(validation);
    final response =
        await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
            .httpsCallable(
              'updateStore',
              options: HttpsCallableOptions(
                timeout: const Duration(seconds: 60),
              ),
            )
            .call({
              'storeId': storeId,
              'name': name,
              'address': address.toMap(),
            });
    final data = Map<String, dynamic>.from(response.data as Map);
    return StoreInfo(
      id: data['id'] as String,
      name: data['name'] as String,
      code: data['code'] as String,
      shopAddress: data['shopAddress'] as String,
      address: StoreAddress.fromMap(data['address']),
      logoPath: data['logoPath'] as String?,
      status: data['status'] as String? ?? 'active',
      currency: data['currency'] as String? ?? 'MYR',
    );
  }

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

  Future<StoreInfo> createStore({
    required String name,
    required StoreAddress address,
  }) async {
    final validation =
        storeNameError(name) ?? shopAddressError(address.formatted);
    if (validation != null) throw ArgumentError(validation);
    final response =
        await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
            .httpsCallable(
              'createStore',
              options: HttpsCallableOptions(
                timeout: const Duration(seconds: 60),
              ),
            )
            .call({'name': name, 'address': address.toMap()});
    final data = Map<String, dynamic>.from(response.data as Map);
    return StoreInfo(
      id: data['id'] as String,
      name: data['name'] as String,
      code: data['code'] as String,
      shopAddress: data['shopAddress'] as String,
      address: StoreAddress.fromMap(data['address']),
    );
  }

  Future<void> saveActiveStore(String storeId) =>
      _db.collection('users').doc(_user.uid).set({
        'activeStoreId': storeId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Stream<List<Map<String, dynamic>>> watchStoreMembers() => _storeRef
      .collection('members')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs.map((doc) {
          return <String, dynamic>{'id': doc.id, ...doc.data()};
        }).toList(),
      );

  Stream<List<Map<String, dynamic>>> watchAdminInvites() => _storeRef
      .collection('adminInvites')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs.map((doc) {
          return <String, dynamic>{'id': doc.id, ...doc.data()};
        }).toList(),
      );

  Future<void> inviteAdmin(String email) async {
    final normalized = email.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalized)) {
      throw ArgumentError('Enter a valid email address.');
    }
    if (normalized.contains('/')) {
      throw ArgumentError('This email address cannot be used.');
    }
    if (normalized == _user.email?.trim().toLowerCase()) {
      throw ArgumentError('The store owner already has full access.');
    }
    await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
        .httpsCallable('createAdminInvite')
        .call({'storeId': _storeId, 'email': normalized});
  }

  Future<void> setMemberActive(String uid, bool isActive) =>
      _storeRef.collection('members').doc(uid).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Stream<List<String>> watchCategories() => watchCategoryRecords().map(
    (categories) =>
        categories.where((c) => c.active).map((c) => c.name).toList(),
  );

  Stream<List<InventoryBatch>> watchInventory() => _storeRef
      .collection('inventoryBatches')
      .orderBy('expiryAt')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(InventoryBatch.fromDoc).toList());

  Stream<List<StoreCategory>> watchCategoryRecords() =>
      _storeRef.collection('categories').snapshots().map((s) {
        final result = s.docs.map(StoreCategory.fromDoc).toList();
        result.sort(StoreCategory.compare);
        return result;
      });

  Future<void> saveCategory(
    String name, {
    String? id,
    bool active = true,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 60) {
      throw ArgumentError('Use a category name of 1–60 characters.');
    }
    final categoryId =
        id ??
        trimmed
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), '-')
            .replaceAll('/', '-');
    if (categoryId == '.' || categoryId == '..') {
      throw ArgumentError('Use a descriptive category name.');
    }
    final ref = _storeRef.collection('categories').doc(categoryId);
    final existingCategories = id == null
        ? await _storeRef.collection('categories').get()
        : null;
    final nextOrder =
        existingCategories == null || existingCategories.docs.isEmpty
        ? 0
        : existingCategories.docs
                  .map((doc) => (doc.data()['sortOrder'] as num? ?? 0).toInt())
                  .reduce((a, b) => a > b ? a : b) +
              1;
    await _db.runTransaction((tx) async {
      final existing = await tx.get(ref);
      if (id == null && existing.exists) {
        throw StateError(
          'This category already exists. Restore it if archived.',
        );
      }
      tx.set(ref, {
        'storeId': _storeId,
        'name': categoryTitleCase(trimmed),
        'slug': categoryId,
        'isActive': active,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
        if (!existing.exists) 'sortOrder': nextOrder,
      }, SetOptions(merge: true));
    });
  }

  Future<void> reorderCategories(List<StoreCategory> categories) async {
    final write = _db.batch();
    for (var index = 0; index < categories.length; index++) {
      write.update(
        _storeRef.collection('categories').doc(categories[index].id),
        {'sortOrder': index, 'updatedAt': FieldValue.serverTimestamp()},
      );
    }
    await write.commit();
  }

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

  Future<BarcodeProduct?> findProductByBarcode(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return null;
    final store = _storeRef;
    final snapshot = await store
        .collection('products')
        .where('barcode', isEqualTo: code)
        .get();
    return latestBarcodeProduct(
      snapshot.docs.map(
        (doc) => BarcodeProduct.fromData(doc.id, store.id, doc.data()),
      ),
    );
  }

  Future<void> saveInventoryDraft(InventoryItemInput input) =>
      saveInventoryItem(
        existing: input.existing,
        reusedProduct: input.reusedProduct,
        name: input.name,
        category: input.category,
        unitLabel: input.unitLabel,
        barcode: input.barcode,
        expiryAt: input.expiryAt,
        quantity: input.quantity,
        basePriceCents: input.basePriceCents,
        promotionEnabled: input.promotionEnabled,
        promotionPriceCents: input.promotionPriceCents,
        notifyOnExpiry: input.notifyOnExpiry,
        image: input.image,
      );

  Future<void> saveInventoryItem({
    InventoryBatch? existing,
    BarcodeProduct? reusedProduct,
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
    final productName = capitalizeProductName(name.trim());
    if (quantity < 0) throw ArgumentError('Quantity cannot be negative.');
    if (basePriceCents < 0) throw ArgumentError('Price cannot be negative.');
    if (promotionEnabled &&
        (promotionPriceCents == null || promotionPriceCents < 0)) {
      throw ArgumentError('Enter a valid promotion price.');
    }

    if (reusedProduct != null &&
        (existing != null ||
            reusedProduct.storeId != _storeId ||
            reusedProduct.barcode != barcode?.trim())) {
      throw ArgumentError('Look up the barcode again for the selected store.');
    }
    final productRef = existing == null
        ? _storeRef.collection('products').doc(reusedProduct?.id)
        : _storeRef.collection('products').doc(existing.productId);
    final batchRef = existing == null
        ? _storeRef.collection('inventoryBatches').doc()
        : _storeRef.collection('inventoryBatches').doc(existing.id);
    final uploadedPath = await uploadProductImage(image, productRef.id);
    final imagePath =
        uploadedPath ?? existing?.imagePath ?? reusedProduct?.imagePath;
    final categoryId = category;
    final write = _db.batch();
    final productData = <String, dynamic>{
      'storeId': _storeId,
      'name': productName,
      'nameLowercase': productName.toLowerCase(),
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
      'productName': productName,
      'productNameLowercase': productName.toLowerCase(),
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
      if (reusedProduct == null) {
        productData['createdAt'] = FieldValue.serverTimestamp();
      }
      inventoryData['createdAt'] = FieldValue.serverTimestamp();
    }
    write.set(productRef, productData, SetOptions(merge: true));
    write.set(batchRef, inventoryData, SetOptions(merge: true));
    if (existing == null) {
      write.set(_storeRef.collection('inventoryEvents').doc(), {
        'storeId': _storeId,
        'batchId': batchRef.id,
        'productId': productRef.id,
        'productName': productName,
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
        'productName': productName,
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
      if (!batchSnap.exists) {
        throw StateError('This item is no longer available.');
      }
      final currentBatch = InventoryBatch.fromDoc(batchSnap);
      if (!currentBatch.canSellAt(DateTime.now())) {
        throw StateError('This item is no longer available.');
      }
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
    if (!batch.exists) throw StateError('This item is no longer available.');
    final current = InventoryBatch.fromDoc(batch);
    if (!current.canSellAt(DateTime.now())) {
      throw StateError('This item is no longer available.');
    }
    final available = current.availableQuantity;
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
    if (fulfillmentType != 'delivery') {
      throw ArgumentError('Only delivery orders are supported.');
    }
    if (!const {'Bank transfer', 'Touch n Go'}.contains(paymentMethod)) {
      throw ArgumentError('Select a supported payment method.');
    }
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
    final deliveryFee =
        (settings.data()?['deliveryFeeCents'] as num?)?.round() ?? 500;
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
        if (!batch.canSellAt(DateTime.now())) {
          throw StateError(
            '${line.productName} is no longer available. Please remove it from your cart.',
          );
        }
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

  Future<InventoryBatch?> findSellingOrderProduct(OrderLine line) async {
    final batches = _storeRef.collection('inventoryBatches');
    final List<InventoryBatch> inventory;
    if (line.productId.isNotEmpty) {
      final snapshot = await batches
          .where('productId', isEqualTo: line.productId)
          .get(const GetOptions(source: Source.server));
      inventory = snapshot.docs.map(InventoryBatch.fromDoc).toList();
    } else if (line.batchId.isNotEmpty) {
      final snapshot = await batches
          .doc(line.batchId)
          .get(const GetOptions(source: Source.server));
      inventory = snapshot.exists ? [InventoryBatch.fromDoc(snapshot)] : [];
    } else {
      return null;
    }
    return sellingOrderProduct(line, inventory, DateTime.now());
  }

  Future<InventoryBatch?> findSavedOrderItem(OrderLine line) async {
    if (line.batchId.isEmpty) return null;
    final snapshot = await _storeRef
        .collection('inventoryBatches')
        .doc(line.batchId)
        .get(const GetOptions(source: Source.server));
    if (!snapshot.exists) return null;
    final item = InventoryBatch.fromDoc(snapshot);
    if (line.productId.isNotEmpty && item.productId != line.productId) {
      return null;
    }
    return item;
  }

  Future<String> uploadOrderReceipt(XFile file, String orderId) async {
    final bytes = await file.readAsBytes();
    final extension = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : 'jpg';
    final ref = _storage.ref(
      'stores/$_storeId/order-attachments/$orderId/receipt.$extension',
    );
    await ref.putData(
      bytes,
      SettableMetadata(contentType: file.mimeType ?? 'image/jpeg'),
    );
    await _storeRef.collection('orders').doc(orderId).update({
      'receiptPath': ref.fullPath,
      'receiptUploadedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.fullPath;
  }

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

  Future<void> updateUserProfile({
    required String displayName,
    required String phoneNumber,
    XFile? photo,
  }) async {
    final nameError = profileNameError(displayName);
    final phoneError = profilePhoneError(phoneNumber);
    if (nameError != null || phoneError != null) {
      throw ArgumentError(nameError ?? phoneError);
    }
    final user = _user;
    final userRef = _db.collection('users').doc(user.uid);
    final previous = await userRef.get();
    final previousName = user.displayName;
    final oldPhoto = previous.data()?['photoPath'] as String?;
    Reference? uploaded;
    var authUpdated = false;
    try {
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        if (bytes.length >= 5 * 1024 * 1024) {
          throw ArgumentError('Choose a photo smaller than 5 MB.');
        }
        final extension = photo.name.split('.').last.toLowerCase();
        final contentType =
            photo.mimeType ??
            switch (extension) {
              'png' => 'image/png',
              'webp' => 'image/webp',
              'gif' => 'image/gif',
              _ => 'image/jpeg',
            };
        uploaded = _storage.ref(
          'user-avatars/${user.uid}/avatar-${DateTime.now().microsecondsSinceEpoch}.$extension',
        );
        await uploaded.putData(
          bytes,
          SettableMetadata(contentType: contentType),
        );
      }
      await user.updateDisplayName(displayName.trim());
      authUpdated = true;
      await userRef.set({
        'displayName': displayName.trim(),
        'phoneNumber': phoneNumber.trim(),
        if (uploaded != null) 'photoPath': uploaded.fullPath,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      if (authUpdated) {
        try {
          await user.updateDisplayName(previousName);
        } catch (_) {
          /* Retry remains available. */
        }
      }
      if (uploaded != null) {
        try {
          await uploaded.delete();
        } catch (_) {
          /* Do not mask the save error. */
        }
      }
      rethrow;
    }
    if (uploaded != null &&
        oldPhoto?.startsWith('user-avatars/${user.uid}/') == true) {
      try {
        await _storage.ref(oldPhoto).delete();
      } catch (_) {
        /* The new profile is already saved. */
      }
    }
  }

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
