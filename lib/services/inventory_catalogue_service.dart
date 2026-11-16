import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/barcode_product.dart';
import '../models/product_name.dart';
import 'image_upload.dart';
import 'store_session.dart';

// Edit reusable product details without changing received stock or orders.
class InventoryCatalogueDraft {
  const InventoryCatalogueDraft({
    required this.product,
    required this.name,
    required this.categoryId,
    required this.unitLabel,
    required this.barcode,
    required this.basePriceCents,
    this.image,
  });

  final BarcodeProduct product;
  final String name, categoryId, unitLabel, barcode;
  final int basePriceCents;
  final XFile? image;

  // Keep validation identical for the form and the saved request.
  void validate() {
    if (name.trim().isEmpty || name.trim().length > 160) {
      throw ArgumentError('Enter a product name of 1–160 characters.');
    }
    if (barcode.trim().isEmpty || barcode.trim().length > 100) {
      throw ArgumentError('Enter a barcode of 1–100 characters.');
    }
    if (unitLabel.trim().isEmpty || unitLabel.trim().length > 40) {
      throw ArgumentError('Enter a unit of 1–40 characters.');
    }
    if (categoryId.isEmpty ||
        categoryId.contains('/') ||
        categoryId == '.' ||
        categoryId == '..') {
      throw ArgumentError('Choose a category.');
    }
    if (basePriceCents <= 0 || basePriceCents > 1000000000) {
      throw ArgumentError('Enter a valid price greater than zero.');
    }
  }
}

class InventoryCatalogueService {
  InventoryCatalogueService._();
  static final instance = InventoryCatalogueService._();

  // Capture the selected shop before starting a request.
  DocumentReference<Map<String, dynamic>> _adminStore() {
    final session = StoreSession.instance;
    if (FirebaseAuth.instance.currentUser == null ||
        !session.canManage ||
        session.storeId == null) {
      throw StateError('Admin access to the selected store is required.');
    }
    return FirebaseFirestore.instance.collection('stores').doc(session.storeId);
  }

  Stream<List<BarcodeProduct>> watchProducts() {
    final store = _adminStore();
    return store.collection('products').snapshots().map((snapshot) {
      final products = snapshot.docs
          .where((doc) => doc.data()['isActive'] != false)
          .map((doc) => BarcodeProduct.fromData(doc.id, store.id, doc.data()))
          .toList();
      products.sort((a, b) {
        final name = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        return name != 0 ? name : a.id.compareTo(b.id);
      });
      return products;
    });
  }

  // Firestore rules also verify the current active Admin membership.
  void _checkScope(BarcodeProduct product, String storeId) {
    if (product.storeId != storeId ||
        StoreSession.instance.storeId != storeId ||
        !StoreSession.instance.canManage) {
      throw StateError('Reopen this product in the selected store.');
    }
  }

  Future<void> saveProduct(InventoryCatalogueDraft draft) async {
    draft.validate();
    final store = _adminStore();
    _checkScope(draft.product, store.id);
    final product = store.collection('products').doc(draft.product.id);
    String? uploadedPath;
    if (draft.image != null) {
      final upload = await ImageUpload.read(draft.image!);
      // Keep images already referenced by older stock and orders unchanged.
      final ref = FirebaseStorage.instance.ref(
        'stores/${store.id}/product-images/${product.id}/'
        'catalogue-${DateTime.now().microsecondsSinceEpoch}.${upload.extension}',
      );
      await ref.putData(
        upload.bytes,
        SettableMetadata(contentType: upload.contentType),
      );
      uploadedPath = ref.fullPath;
    }
    _checkScope(draft.product, store.id);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final current = await transaction.get(product);
      final category = await transaction.get(
        store.collection('categories').doc(draft.categoryId),
      );
      if (!current.exists) {
        throw StateError('This saved product was deleted. Reopen the list.');
      }
      if (!category.exists ||
          (category.data()?['isActive'] != true &&
              current.data()?['categoryId'] != draft.categoryId)) {
        throw StateError('Choose an available category.');
      }
      final name = capitalizeProductName(draft.name.trim());
      transaction.update(product, {
        'name': name,
        'barcode': draft.barcode.trim(),
        'categoryId': draft.categoryId,
        'unitLabel': draft.unitLabel.trim(),
        'basePriceCents': draft.basePriceCents,
        'imagePath': ?uploadedPath,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // Delete only the lookup entry; received batches keep their own snapshots.
  Future<void> deleteProduct(BarcodeProduct product) async {
    final store = _adminStore();
    _checkScope(product, store.id);
    await store.collection('products').doc(product.id).delete();
  }
}
