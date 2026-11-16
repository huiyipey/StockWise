import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'cart_item_data.dart';
import '../models/store_hours.dart';
import '../models/shelf_life.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_models.dart';
import '../models/store_address.dart';
import '../models/barcode_product.dart';
import '../models/product_name.dart';
import '../models/category_label.dart';
import '../models/report_email_schedule.dart';
import '../models/store_role.dart';
import 'profile_fields.dart';
import 'store_fields.dart';
import 'order_product.dart';
import 'store_session.dart';
import 'local_database.dart';
import 'catalogue_cache.dart';
import 'inventory_receiving.dart';
import 'image_upload.dart';

// Read shop data and send validated business actions to Firebase.
class FirestoreService {
  FirestoreService._()
    : _db = FirebaseFirestore.instance,
      _storage = FirebaseStorage.instance,
      _auth = FirebaseAuth.instance,
      _selectedStoreId = (() => StoreSession.instance.storeId);

  // Exercise real transactions with isolated accounts and database clients.
  @visibleForTesting
  factory FirestoreService.forInventoryTesting({
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
    required FirebaseAuth auth,
    required String? Function() selectedStoreId,
  }) =>
      FirestoreService._withClients(firestore, storage, auth, selectedStoreId);

  FirestoreService._withClients(
    this._db,
    this._storage,
    this._auth,
    this._selectedStoreId,
  );

  static final FirestoreService instance = FirestoreService._();
  String? _pendingCheckoutId;
  // Send the selected shop ID with a commerce request.
  Future<Map<String, dynamic>> callCommerce(
    String name,
    Map<String, dynamic> data,
  ) async {
    try {
      final result =
          await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
              .httpsCallable(
                name,
                options: HttpsCallableOptions(
                  timeout: Duration(seconds: name == 'deleteStore' ? 540 : 120),
                ),
              )
              .call({'storeId': _storeId, ...data});
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      throw StateError(e.message ?? 'Please try again.');
    }
  }

  // Request authoritative prices, offers, and delivery totals.
  Future<Map<String, dynamic>> quoteCart(String postcode) =>
      callCommerce('quoteCart', {'postcode': postcode});
  // Watch the selected shop delivery settings.
  Stream<Map<String, dynamic>> watchCommerceSettings() => _storeRef
      .collection('settings')
      .doc('commerce')
      .snapshots()
      .map((s) => s.data() ?? {});
  // Save validated fixed or postcode-based fees on the server.
  Future<void> saveDeliveryFees({
    required String mode,
    required int fixedCents,
    required Map<String, int> postcodeFees,
  }) async {
    await callCommerce('saveDeliveryFees', {
      'mode': mode,
      'fixedCents': fixedCents,
      'postcodeFees': postcodeFees,
    });
  }

  // Save the current admin report-email switch.
  Future<void> setReportEmailPreference(bool enabled) =>
      _storeRef.collection('members').doc(_user.uid).update({
        'reportsByEmail': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      });
  // Watch this admin report-email switch for this shop.
  Stream<bool> watchReportEmailPreference() => _storeRef
      .collection('members')
      .doc(_user.uid)
      .snapshots()
      .map((s) => s.data()?['reportsByEmail'] as bool? ?? true);
  // Watch the independent sales and waste email schedules.
  Stream<ReportEmailSchedule> watchReportEmailSchedule() => _storeRef
      .collection('members')
      .doc(_user.uid)
      .snapshots()
      .map((s) => ReportEmailSchedule.fromMember(s.data() ?? {}));
  // Save this admin selected sales and waste schedules.
  Future<void> saveReportEmailSchedule(ReportEmailSchedule value) =>
      _storeRef.collection('members').doc(_user.uid).update({
        'reportsByEmail': value.enabled,
        'reportEmailSchedules': value.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
  // Delete the named shop through the guarded server action.
  Future<void> deleteStore(StoreInfo store) async {
    try {
      await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
          .httpsCallable(
            'deleteStore',
            options: HttpsCallableOptions(
              timeout: const Duration(seconds: 540),
            ),
          )
          .call({'storeId': store.id, 'confirmName': store.name});
      await LocalDatabase.instance.removeStore(LocalScope(_user.uid, store.id));
    } on FirebaseFunctionsException catch (e) {
      throw StateError(e.message ?? 'Could not delete this store.');
    }
  }

  // Watch one inventory batch in this shop.
  Stream<InventoryBatch?> watchInventoryBatch(String id) => _storeRef
      .collection('inventoryBatches')
      .doc(id)
      .snapshots()
      .map((s) => s.exists ? InventoryBatch.fromDoc(s) : null);
  // Load one inventory batch from this shop.
  Future<InventoryBatch?> getInventoryBatch(String id) async {
    final s = await _storeRef.collection('inventoryBatches').doc(id).get();
    return s.exists ? InventoryBatch.fromDoc(s) : null;
  }

  // Archive or remove the selected inventory batch.
  Future<void> removeInventory(InventoryBatch item) async {
    await callCommerce('removeInventory', {'batchId': item.id});
  }

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;
  final String? Function() _selectedStoreId;

  // Require the currently signed-in Firebase account.
  User get _user {
    final user = _auth.currentUser;
    if (user == null) throw StateError('You must be signed in.');
    return user;
  }

  // Require the selected shop identifier.
  String get _storeId {
    final storeId = _selectedStoreId();
    if (storeId == null) throw StateError('Select a store first.');
    return storeId;
  }

  // Build the Firestore reference for the selected shop.
  DocumentReference<Map<String, dynamic>> get _storeRef =>
      _db.collection('stores').doc(_storeId);

  // Create missing profile fields and accept valid admin invitations.
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

  // Accept matching invitations without replacing existing preferences.
  Future<void> _acceptAdminInvitations(String emailLowercase) async {
    final invitations = await _db
        .collectionGroup('adminInvites')
        .where('emailLowercase', isEqualTo: emailLowercase)
        .get();
    for (final invitation in invitations.docs) {
      final storeRef = invitation.reference.parent.parent;
      if (storeRef == null ||
          storeRef.parent.id != 'stores' ||
          !isAcceptableAdminInvitation(
            invitation.data(),
            storeId: storeRef.id,
            emailLowercase: emailLowercase,
          )) {
        continue;
      }
      final memberRef = storeRef.collection('members').doc(_user.uid);
      await _db.runTransaction((transaction) async {
        final currentInvite = await transaction.get(invitation.reference);
        final currentMember = await transaction.get(memberRef);
        if (!isAcceptableAdminInvitation(
          currentInvite.data(),
          storeId: storeRef.id,
          emailLowercase: emailLowercase,
        )) {
          return;
        }
        final currentData = currentMember.data();
        if (currentData?['isActive'] != true ||
            !isStoreAdminRole(currentData?['role'])) {
          transaction.set(memberRef, {
            'storeId': storeRef.id,
            'userId': _user.uid,
            'email': _user.email,
            'role': 'admin',
            'isActive': true,
            'invitationId': invitation.id,
            if (currentData?['joinedAt'] == null)
              'joinedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        transaction.update(invitation.reference, {
          'status': 'accepted',
          'acceptedBy': _user.uid,
          'acceptedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    }
  }

  // Build an initial display name from the email address.
  String _nameFromEmail(String? email) {
    final local = (email ?? 'StockWise User').split('@').first;
    return local
        .split(RegExp(r'[._-]'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  // Watch shops available to the account.
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

  // Watch the selected shop details.
  Stream<StoreInfo?> watchSelectedStore() => _storeRef.snapshots().map(
    (snapshot) => snapshot.exists ? StoreInfo.fromDoc(snapshot) : null,
  );

  // Save shop details through the validated server action.
  Future<StoreInfo> updateStore({
    required String storeId,
    required String name,
    required StoreAddress address,
    StoreHours? operatingHours,
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
              if (operatingHours != null)
                'operatingHours': operatingHours.toMap(),
            });
    final data = Map<String, dynamic>.from(response.data as Map);
    return StoreInfo(
      id: data['id'] as String,
      name: data['name'] as String,
      code: data['code'] as String,
      shopAddress: data['shopAddress'] as String,
      address: StoreAddress.fromMap(data['address']),
      operatingHours: StoreHours.fromMap(data['operatingHours']),
      logoPath: data['logoPath'] as String?,
      status: data['status'] as String? ?? 'active',
      currency: data['currency'] as String? ?? 'MYR',
    );
  }

  // Watch the account memberships across shops.
  Stream<List<StoreMembership>> watchMyMemberships() {
    final userId = _user.uid;
    return _db
        .collectionGroup('members')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(StoreMembership.fromDoc)
              .where(
                (membership) =>
                    membership.userId == userId && membership.isActive,
              )
              .toList(),
        );
  }

  // Read the current account identifier.
  String get currentUserId => _user.uid;

  // Create the shop and its initial Admin membership.
  Future<StoreInfo> createStore({
    required String name,
    required StoreAddress address,
    StoreHours? operatingHours,
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
            .call({
              'name': name,
              'address': address.toMap(),
              if (operatingHours != null)
                'operatingHours': operatingHours.toMap(),
            });
    final data = Map<String, dynamic>.from(response.data as Map);
    return StoreInfo(
      id: data['id'] as String,
      name: data['name'] as String,
      code: data['code'] as String,
      shopAddress: data['shopAddress'] as String,
      address: StoreAddress.fromMap(data['address']),
      operatingHours: StoreHours.fromMap(data['operatingHours']),
    );
  }

  // Remember the last shop selected by this account.
  Future<void> saveActiveStore(String storeId) =>
      _db.collection('users').doc(_user.uid).set({
        'activeStoreId': storeId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  // Watch the selected shop admin memberships.
  Stream<List<Map<String, dynamic>>> watchStoreMembers() => _storeRef
      .collection('members')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs.map((doc) {
          return <String, dynamic>{'id': doc.id, ...doc.data()};
        }).toList(),
      );

  // Watch pending admin invitations for this shop.
  Stream<List<Map<String, dynamic>>> watchAdminInvites() => _storeRef
      .collection('adminInvites')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs.map((doc) {
          return <String, dynamic>{'id': doc.id, ...doc.data()};
        }).toList(),
      );

  // Invite an existing account through the server.
  Future<void> inviteAdmin(String email) async {
    final normalized = email.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalized)) {
      throw ArgumentError('Enter a valid email address.');
    }
    if (normalized.contains('/')) {
      throw ArgumentError('This email address cannot be used.');
    }
    if (normalized == _user.email?.trim().toLowerCase()) {
      throw ArgumentError('You already have admin access to this store.');
    }
    await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
        .httpsCallable('createAdminInvite')
        .call({'storeId': _storeId, 'email': normalized});
  }

  // Change admin access with last-admin protection.
  Future<void> setMemberActive(String uid, bool isActive) async {
    await callCommerce('setStoreAdminActive', {
      'userId': uid,
      'isActive': isActive,
    });
  }

  // Watch categories for the selected shop.
  Stream<List<String>> watchCategories() => watchCategoryRecords().map(
    (categories) =>
        categories.where((c) => c.active).map((c) => c.name).toList(),
  );

  // Watch inventory with a local cache fallback.
  Stream<List<InventoryBatch>> watchInventory() {
    final scope = LocalScope(_user.uid, _storeId);
    final remote = _db
        .collection('stores')
        .doc(scope.storeId)
        .collection('inventoryBatches')
        .orderBy('expiryAt')
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => RemoteCatalogue(
            snapshot.docs.map(InventoryBatch.fromDoc).toList(),
            fromServer: !snapshot.metadata.isFromCache,
            pending: snapshot.metadata.hasPendingWrites,
          ),
        );
    return CatalogueCache.instance.inventory(scope, remote);
  }

  // Watch category records with a local cache fallback.
  Stream<List<StoreCategory>> watchCategoryRecords() {
    final scope = LocalScope(_user.uid, _storeId);
    final remote = _db
        .collection('stores')
        .doc(scope.storeId)
        .collection('categories')
        .snapshots(includeMetadataChanges: true)
        .map((s) {
          final result = s.docs.map(StoreCategory.fromDoc).toList();
          result.sort(StoreCategory.compare);
          return RemoteCatalogue(
            result,
            fromServer: !s.metadata.isFromCache,
            pending: s.metadata.hasPendingWrites,
          );
        });
    return CatalogueCache.instance.categories(scope, remote);
  }

  // Add or rename a category without recreating deleted records.
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
      if (id != null && !existing.exists) {
        throw StateError(
          'This category was deleted. Reopen the categories page.',
        );
      }
      tx.set(ref, {
        'storeId': _storeId,
        'name': categoryTitleCase(trimmed),
        'isActive': active,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
        if (!existing.exists) 'sortOrder': nextOrder,
      }, SetOptions(merge: true));
    });
  }

  // Ask the server to delete an unused category.
  Future<void> deleteCategory(String id) async {
    await callCommerce('deleteCategory', {'categoryId': id});
  }

  // Save the category display order.
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

  // Watch active promotional inventory batches.
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

  // Upload a validated product image to this shop.
  Future<String?> uploadProductImage(
    XFile? file,
    String productId, {
    String? storeId,
  }) async {
    if (file == null) return null;
    final selectedStoreId = storeId ?? _storeId;
    final upload = await ImageUpload.read(file);
    // Preserve images already referenced by other batches and order history.
    final ref = _storage.ref(
      'stores/$selectedStoreId/product-images/$productId/'
      'inventory-${DateTime.now().microsecondsSinceEpoch}.${upload.extension}',
    );
    await ref.putData(
      upload.bytes,
      SettableMetadata(contentType: upload.contentType),
    );
    return ref.fullPath;
  }

  // Find saved product details for the scanned barcode.
  Future<BarcodeProduct?> findProductByBarcode(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return null;
    final store = _storeRef;
    final snapshot = await store
        .collection('products')
        .where('barcode', isEqualTo: code)
        .get();
    return latestBarcodeProduct(
      snapshot.docs
          .where((doc) => doc.data()['isActive'] != false)
          .map((doc) => BarcodeProduct.fromData(doc.id, store.id, doc.data())),
    );
  }

  // Convert the editor draft to validated inventory input.
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
        promotion: input.promotion,
        notifyOnExpiry: input.notifyOnExpiry,
        image: input.image,
      );

  // Save product details and the inventory batch together.
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
    Map<String, dynamic>? promotion,
    required bool notifyOnExpiry,
    XFile? image,
  }) async {
    final store = _storeRef;
    final storeId = store.id;
    final actorUid = _user.uid;
    void checkScope() {
      if (_auth.currentUser?.uid != actorUid || _selectedStoreId() != storeId) {
        throw StateError('Reopen this item in the selected store.');
      }
    }

    if (name.trim().isEmpty) throw ArgumentError('Product name is required.');
    final productName = capitalizeProductName(name.trim());
    if (quantity < 1) throw ArgumentError('Enter a valid quantity.');
    if (basePriceCents <= 0) {
      throw ArgumentError('Enter a price greater than zero.');
    }
    if (existing != null && !existing.expiryAt.isAfter(DateTime.now())) {
      throw StateError('Expired inventory cannot be edited.');
    }
    if (promotionEnabled &&
        promotion?['type'] != 'bundle' &&
        (promotionPriceCents == null || promotionPriceCents <= 0)) {
      throw ArgumentError('Enter a valid promotion price.');
    }

    if (reusedProduct != null &&
        (reusedProduct.storeId != storeId ||
            reusedProduct.barcode != barcode?.trim())) {
      throw ArgumentError('Look up the barcode again for the selected store.');
    }
    if (category.isEmpty ||
        category.contains('/') ||
        category == '.' ||
        category == '..') {
      throw ArgumentError('Choose a valid category.');
    }
    final selectedCategory = await store
        .collection('categories')
        .doc(category)
        .get(const GetOptions(source: Source.server));
    if (!selectedCategory.exists) {
      throw StateError('This category was deleted. Choose another category.');
    }
    final batches = store.collection('inventoryBatches');
    final products = store.collection('products');
    final identity = InventoryReceiptIdentity(
      name: productName,
      categoryId: category,
      unitLabel: unitLabel,
      barcode: barcode,
      basePriceCents: basePriceCents,
      expiryAt: expiryAt,
    );
    final code = barcode?.trim() ?? '';
    final fallbackProduct = products.doc(
      reusedProduct?.id ?? existing?.productId,
    );
    final uploadedPath = await uploadProductImage(
      image,
      fallbackProduct.id,
      storeId: storeId,
    );
    final eventRef = store.collection('inventoryEvents').doc();
    final receivingRevision = store
        .collection('settings')
        .doc('inventoryReceiving');

    checkScope();
    await _db.runTransaction((tx) async {
      checkScope();
      // Serialize receipts and edits so a retry repeats the catalogue lookup.
      final revision = await tx.get(receivingRevision);
      DocumentSnapshot<Map<String, dynamic>>? current;
      DocumentReference<Map<String, dynamic>>? target;
      if (existing != null) {
        target = batches.doc(existing.id);
        current = await tx.get(target);
        if (!current.exists) {
          throw StateError('This item was removed. Reopen the inventory page.');
        }
        if (!InventoryBatch.fromDoc(current).expiryAt.isAfter(DateTime.now())) {
          throw StateError('Expired inventory cannot be edited.');
        }
      } else {
        final candidates =
            (await (code.isEmpty
                        ? batches.where('categoryId', isEqualTo: category)
                        : batches.where('barcode', isEqualTo: code))
                    .get(const GetOptions(source: Source.server)))
                .docs
                .where(
                  (doc) => identity.matches(
                    InventoryBatch.fromDoc(doc),
                    DateTime.now(),
                  ),
                )
                .toList();
        candidates.sort((a, b) => a.id.compareTo(b.id));
        // Recheck older random-ID batches before choosing a new stock record.
        for (final candidate in candidates) {
          final saved = await tx.get(candidate.reference);
          if (saved.exists &&
              identity.matches(InventoryBatch.fromDoc(saved), DateTime.now())) {
            target = candidate.reference;
            current = saved;
            break;
          }
        }
        // Deterministic targets make simultaneous new receipts share one batch.
        for (var suffix = 0; target == null && suffix < 100; suffix++) {
          final ref = batches.doc(
            '${identity.documentId}${suffix == 0 ? '' : '-$suffix'}',
          );
          final saved = await tx.get(ref);
          if (!saved.exists ||
              identity.matches(InventoryBatch.fromDoc(saved), DateTime.now())) {
            target = ref;
            current = saved;
          }
        }
        if (target == null) {
          throw StateError(
            'Could not select a stock record. Please try again.',
          );
        }
      }
      final batchRef = target;
      final savedBatch = current!.exists
          ? InventoryBatch.fromDoc(current)
          : null;
      final merging = existing == null && savedBatch != null;
      final productRef = merging && savedBatch.productId.isNotEmpty
          ? products.doc(savedBatch.productId)
          : fallbackProduct;
      final savedProduct = await tx.get(productRef);
      final previousProduct = savedProduct.data() ?? <String, dynamic>{};
      final previousBatch = current.data() ?? <String, dynamic>{};
      final imagePath =
          uploadedPath ??
          reusedProduct?.imagePath ??
          savedBatch?.imagePath ??
          existing?.imagePath;
      // Keep concurrent receipts and customer reservations when editing stock.
      final quantityDelta = existing == null
          ? quantity
          : quantity - existing.quantityOnHand;
      final nextQuantity = (savedBatch?.quantityOnHand ?? 0) + quantityDelta;
      if (nextQuantity < (savedBatch?.quantityReserved ?? 0)) {
        throw StateError('Quantity cannot be less than the reserved stock.');
      }
      final receivedAt = savedBatch?.receivedAt ?? DateTime.now();
      final productData = <String, dynamic>{
        'storeId': storeId,
        'name': productName,
        'categoryId': category,
        'barcode': code.isEmpty ? null : code,
        'imagePath': imagePath,
        'unitLabel': unitLabel.trim().isEmpty ? 'unit' : unitLabel.trim(),
        'basePriceCents': basePriceCents,
        'currency': 'MYR',
        'isActive': true,
        'createdBy': previousProduct['createdBy'] ?? actorUid,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!savedProduct.exists) 'createdAt': FieldValue.serverTimestamp(),
      };
      final inventoryData = merging
          ? <String, dynamic>{
              'quantityOnHand': nextQuantity,
              'status': 'active',
              'updatedAt': FieldValue.serverTimestamp(),
              'imagePath': ?uploadedPath,
              if (savedBatch.productId.isEmpty) 'productId': productRef.id,
            }
          : <String, dynamic>{
              'storeId': storeId,
              'productId': productRef.id,
              'productName': productName,
              'categoryId': category,
              'barcode': code.isEmpty ? null : code,
              'imagePath': imagePath,
              'unitLabel': unitLabel.trim().isEmpty ? 'unit' : unitLabel.trim(),
              'expiryAt': Timestamp.fromDate(expiryAt),
              'quantityOnHand': nextQuantity,
              'quantityReserved': savedBatch?.quantityReserved ?? 0,
              'basePriceCents': basePriceCents,
              'promotionEnabled': promotionEnabled,
              'promotionPriceCents': promotionEnabled
                  ? promotionPriceCents
                  : null,
              'promotion': promotionEnabled ? promotion : null,
              'receivedAt': Timestamp.fromDate(receivedAt),
              'totalShelfLifeDays': calendarDaysBetween(receivedAt, expiryAt),
              'shelfLifeType': shelfLifeType(
                calendarDaysBetween(receivedAt, expiryAt),
              ).name,
              'notifyOnExpiry': notifyOnExpiry,
              'status': nextQuantity == 0 ? 'depleted' : 'active',
              'createdBy': previousBatch['createdBy'] ?? actorUid,
              'updatedAt': FieldValue.serverTimestamp(),
              if (!current.exists) 'createdAt': FieldValue.serverTimestamp(),
            };
      checkScope();
      tx.set(productRef, productData, SetOptions(merge: true));
      tx.set(batchRef, inventoryData, SetOptions(merge: true));
      tx.set(receivingRevision, {
        'revision': ((revision.data()?['revision'] as num?)?.toInt() ?? 0) + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (quantityDelta != 0) {
        tx.set(eventRef, {
          'storeId': storeId,
          'batchId': batchRef.id,
          'productId': productRef.id,
          'productName': productName,
          'categoryId': category,
          'eventType': existing == null ? 'received' : 'adjusted',
          'quantity': quantityDelta.abs(),
          'quantityDelta': quantityDelta,
          'actorUid': actorUid,
          'occurredAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // Discard the requested stock through the server transaction.
  Future<void> discardBatch(
    InventoryBatch batch, {
    required int quantity,
    String reason = 'discarded',
  }) async {
    await callCommerce('discardInventory', {
      'batchId': batch.id,
      'quantity': quantity,
    });
  }

  // Watch this customer cart in the selected shop.
  Stream<List<CartLine>> watchCart() => _storeRef
      .collection('carts')
      .doc(_user.uid)
      .collection('items')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(CartLine.fromDoc).toList());

  // Add stock to this customer cart within availability limits.
  Future<void> addToCart(InventoryBatch batch, {int quantity = 1}) async {
    if (quantity < 1) throw ArgumentError.value(quantity, 'quantity');
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
      if (currentQuantity + quantity > currentBatch.availableQuantity) {
        throw StateError('Only ${currentBatch.availableQuantity} available.');
      }
      transaction.set(cartRef, {
        'storeId': _storeId,
        'ownerUid': _user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      final itemData = cartItemData(
        storeId: _storeId,
        batchId: batchSnap.id,
        batch: batchSnap.data()!,
        quantity: currentQuantity + quantity,
      )..['updatedAt'] = FieldValue.serverTimestamp();
      if (!itemSnap.exists) {
        itemData['addedAt'] = FieldValue.serverTimestamp();
      }
      transaction.set(itemRef, itemData, SetOptions(merge: true));
    });
  }

  // Save a cart quantity within the available stock.
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
    await _db.runTransaction((transaction) async {
      final batch = await transaction.get(
        _storeRef.collection('inventoryBatches').doc(line.batchId),
      );
      final saved = await transaction.get(ref);
      if (!saved.exists) throw StateError('This cart item has been removed.');
      if (!batch.exists) throw StateError('This item is no longer available.');
      final current = InventoryBatch.fromDoc(batch);
      if (!current.canSellAt(DateTime.now())) {
        throw StateError('This item is no longer available.');
      }
      if (quantity > current.availableQuantity) {
        throw StateError('Only ${current.availableQuantity} available.');
      }
      transaction.set(
        ref,
        cartItemData(
          storeId: _storeId,
          batchId: batch.id,
          batch: batch.data()!,
          quantity: quantity,
        )..['updatedAt'] = FieldValue.serverTimestamp(),
        SetOptions(merge: true),
      );
    });
  }

  // Delete the selected line from this customer cart.
  Future<void> removeCartItem(String id) => _storeRef
      .collection('carts')
      .doc(_user.uid)
      .collection('items')
      .doc(id)
      .delete();

  // Place the quoted order with a stable retry identifier.
  Future<String> placeOrder({
    required String fulfillmentType,
    required Map<String, dynamic> receiver,
    required String paymentMethod,
    int? expectedTotalCents,
    String? acceptedPromotionReviewToken,
  }) async {
    if (fulfillmentType != 'delivery') {
      throw ArgumentError('Only delivery orders are supported.');
    }
    final total =
        expectedTotalCents ??
        (await quoteCart(receiver['postalCode'] as String? ?? ''))['totalCents']
            as int?;
    if (total == null) {
      throw StateError('Delivery is not configured for this postcode.');
    }
    _pendingCheckoutId ??= _db.collection('orders').doc().id;
    final result = await callCommerce('placeOrder', {
      'receiver': receiver,
      'paymentMethod': paymentMethod,
      'requestId': _pendingCheckoutId,
      'expectedTotalCents': total,
      'acceptedPromotionReviewToken': acceptedPromotionReviewToken,
    });
    _pendingCheckoutId = null;
    return result['id'] as String;
  }

  // Watch shop orders allowed for the current role.
  Stream<List<StoreOrder>> watchOrders({required bool admin}) {
    Query<Map<String, dynamic>> query = _storeRef.collection('orders');
    if (!admin) query = query.where('userId', isEqualTo: _user.uid);
    return query.snapshots().map((snapshot) {
      final orders = snapshot.docs.map(StoreOrder.fromDoc).toList();
      orders.sort((a, b) => b.placedAt.compareTo(a.placedAt));
      return orders;
    });
  }

  // Watch the item snapshots saved with this order.
  Stream<List<OrderLine>> watchOrderLines(String orderId) => _storeRef
      .collection('orders')
      .doc(orderId)
      .collection('items')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(OrderLine.fromDoc).toList());

  // Load an order from the selected shop.
  Future<StoreOrder?> getOrder(String orderId) async {
    final doc = await _storeRef
        .collection('orders')
        .doc(orderId)
        .get(const GetOptions(source: Source.server));
    return doc.exists ? StoreOrder.fromDoc(doc) : null;
  }

  // Watch the latest state of this order.
  Stream<StoreOrder?> watchOrder(String orderId) => _storeRef
      .collection('orders')
      .doc(orderId)
      .snapshots()
      .map((snapshot) => snapshot.exists ? StoreOrder.fromDoc(snapshot) : null);

  // Find a currently sellable product matching the order line.
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

  // Load the historical item saved with the order.
  Future<InventoryBatch?> findSavedOrderItem(OrderLine line) async {
    if (line.batchId.isEmpty) return null;
    var snapshot = await _storeRef
        .collection('inventoryBatches')
        .doc(line.batchId)
        .get(const GetOptions(source: Source.server));
    if (!snapshot.exists) {
      snapshot = await _storeRef
          .collection('inventoryArchive')
          .doc(line.batchId)
          .get(const GetOptions(source: Source.server));
    }
    if (!snapshot.exists) return null;
    final item = InventoryBatch.fromDoc(snapshot);
    if (line.productId.isNotEmpty && item.productId != line.productId) {
      return null;
    }
    return item;
  }

  // Upload and save this order payment receipt.
  Future<String> uploadOrderReceipt(XFile file, String orderId) async {
    final bytes = await file.readAsBytes();
    final extension = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : 'jpg';
    final ref = _storage.ref(
      'stores/$_storeId/order-attachments/$orderId/receipt-${DateTime.now().microsecondsSinceEpoch}.$extension',
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

  // Submit the permitted status change to the server.
  Future<void> updateOrderStatus(
    StoreOrder order,
    String status, {
    String? reason,
  }) async {
    await callCommerce('updateOrderStatus', {
      'orderId': order.id,
      'status': status,
      'expectedStatus': order.status,
      'reason': reason,
    });
  }

  // Watch the signed-in account notifications.
  Stream<List<AppNotification>> watchNotifications() => _storeRef
      .collection('notifications')
      .where('recipientUid', isEqualTo: _user.uid)
      .snapshots()
      .map((snapshot) {
        final notices = snapshot.docs.map(AppNotification.fromDoc).toList();
        notices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return notices;
      });

  // Mark this notification as read.
  Future<void> markNotificationRead(String id) => _storeRef
      .collection('notifications')
      .doc(id)
      .update({'readAt': FieldValue.serverTimestamp()});

  // Watch recorded stock waste for the selected shop.
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

  // Watch the signed-in account profile.
  Stream<Map<String, dynamic>> watchUserProfile() => _db
      .collection('users')
      .doc(_user.uid)
      .snapshots()
      .map((doc) => doc.data() ?? const <String, dynamic>{});

  // Validate and save the editable profile fields.
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
    final formattedName = capitalizeProductName(displayName.trim());
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
      await user.updateDisplayName(formattedName);
      authUpdated = true;
      await userRef.set({
        'displayName': formattedName,
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

  // Save the selected account notification preference.
  Future<void> updateNotificationPreference(bool enabled) =>
      _db.collection('users').doc(_user.uid).set({
        'preferences': {
          'expiryAlerts': enabled,
          'orderUpdates': enabled,
          'promotions': enabled,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  // Resolve a stored image path to a download URL.
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
