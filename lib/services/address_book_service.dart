import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/saved_address.dart';
import '../models/store_address.dart';
import 'postcode_lookup.dart';
import 'profile_fields.dart';
import 'store_fields.dart';

// Define the saved-address operations used by the screens.
abstract class AddressBookRepository {
  // Watch saved addresses for the current account.
  Stream<AddressBook> watch();
  // Save the validated address or attachment.
  Future<void> save(SavedAddress address, {bool makeDefault = false});
  // Make this the account default delivery address.
  Future<void> setDefault(String id);
  // Delete the selected saved address.
  Future<void> delete(String id);
}

// Require a non-empty address field.
String? addressRequired(String? value) =>
    value == null || value.trim().isEmpty ? 'Required' : null;

// Validate the receiver Malaysian phone number.
String? addressPhoneError(String? value) =>
    addressRequired(value) ?? profilePhoneError(value);

// Require a supported five-digit Malaysian postcode.
String? addressPostalError(String? value) => postcodeError(value?.trim());

// Read and save account-scoped delivery addresses.
class AddressBookService implements AddressBookRepository {
  AddressBookService._();
  static final instance = AddressBookService._();
  final _db = FirebaseFirestore.instance;

  // Require the signed-in account address collection.
  DocumentReference<Map<String, dynamic>> get _userRef {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Please sign in.');
    return _db.collection('users').doc(uid);
  }

  // Watch the account addresses and selected default.
  @override
  Stream<AddressBook> watch() {
    final user = _userRef;
    return Stream.multi((controller) {
      List<SavedAddress>? rows;
      String? defaultId;
      var profileReady = false;
      // Publish the latest saved address book.
      void emit() {
        if (rows != null && profileReady) {
          controller.add(
            AddressBook(addresses: rows!, defaultAddressId: defaultId),
          );
        }
      }

      final profile = user.snapshots().listen((snapshot) {
        defaultId = snapshot.data()?['defaultAddressId'] as String?;
        profileReady = true;
        emit();
      }, onError: controller.addError);
      final addresses = user.collection('addresses').snapshots().listen((
        snapshot,
      ) {
        rows = snapshot.docs.map(SavedAddress.fromDoc).toList()
          ..sort((a, b) {
            final labels = a.label.toLowerCase().compareTo(
              b.label.toLowerCase(),
            );
            return labels != 0 ? labels : a.id.compareTo(b.id);
          });
        emit();
      }, onError: controller.addError);
      controller.onCancel = () async {
        await Future.wait([profile.cancel(), addresses.cancel()]);
      };
    });
  }

  // Save the validated address and preserve a valid default.
  @override
  Future<void> save(SavedAddress address, {bool makeDefault = false}) async {
    final data = address.toData();
    final error =
        addressRequired(address.label) ??
        (address.label.trim().length > 40
            ? 'Use 40 characters or fewer'
            : null) ??
        profileNameError(address.name) ??
        addressPhoneError(address.phone) ??
        addressLineError(address.addressLine1) ??
        addressLineError(address.addressLine2, required: false) ??
        cityError(address.city) ??
        addressPostalError(address.postalCode);
    if (error != null) throw ArgumentError(error);
    final location = await MalaysianPostcodes.lookup(address.postalCode.trim());
    if (location == null) {
      throw ArgumentError('Postcode not found. Check the number.');
    }
    data['state'] = location.state;
    final completeAddress = StoreAddress(
      line1: address.addressLine1,
      line2: address.addressLine2,
      postcode: address.postalCode,
      city: address.city,
      state: location.state,
    );
    final combinedError = shopAddressError(completeAddress.formatted);
    if (combinedError != null) throw ArgumentError(combinedError);
    final user = _userRef;
    final addresses = user.collection('addresses');
    final ref = address.id.isEmpty
        ? addresses.doc()
        : addresses.doc(address.id);
    await _db.runTransaction((transaction) async {
      final profile = await transaction.get(user);
      final previous = await transaction.get(ref);
      final defaultId = profile.data()?['defaultAddressId'] as String?;
      var hasDefault = defaultId == ref.id && previous.exists;
      if (defaultId != null && defaultId != ref.id) {
        hasDefault = (await transaction.get(addresses.doc(defaultId))).exists;
      }
      transaction.set(ref, {
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!previous.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (makeDefault || !hasDefault) {
        transaction.set(user, {
          'defaultAddressId': ref.id,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }

  // Make this the account default delivery address.
  @override
  Future<void> setDefault(String id) async {
    final user = _userRef;
    await _db.runTransaction((transaction) async {
      if (!(await transaction.get(
        user.collection('addresses').doc(id),
      )).exists) {
        throw StateError('This address is no longer available.');
      }
      transaction.set(user, {
        'defaultAddressId': id,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  // Delete the address and replace its default when needed.
  @override
  Future<void> delete(String id) async {
    final user = _userRef;
    final addresses = user.collection('addresses');
    final candidates = (await addresses.get()).docs
        .where((doc) => doc.id != id)
        .toList();
    await _db.runTransaction((transaction) async {
      final profile = await transaction.get(user);
      final removingDefault = profile.data()?['defaultAddressId'] == id;
      String? nextDefault;
      if (removingDefault) {
        for (final candidate in candidates) {
          if ((await transaction.get(candidate.reference)).exists) {
            nextDefault = candidate.id;
            break;
          }
        }
      }
      transaction.delete(addresses.doc(id));
      if (removingDefault) {
        transaction.set(user, {
          'defaultAddressId': nextDefault ?? FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }
}
