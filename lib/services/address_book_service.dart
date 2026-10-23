import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/saved_address.dart';
import 'profile_fields.dart';

abstract class AddressBookRepository {
  Stream<AddressBook> watch();
  Future<void> save(SavedAddress address, {bool makeDefault = false});
  Future<void> setDefault(String id);
  Future<void> delete(String id);
}

String? addressRequired(String? value) =>
    value == null || value.trim().isEmpty ? 'Required' : null;

String? addressPhoneError(String? value) =>
    addressRequired(value) ?? profilePhoneError(value);

String? addressPostalError(String? value) =>
    RegExp(r'^\d{5}$').hasMatch(value?.trim() ?? '')
    ? null
    : 'Enter a 5-digit postal code';

class AddressBookService implements AddressBookRepository {
  AddressBookService._();
  static final instance = AddressBookService._();
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _userRef {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Please sign in.');
    return _db.collection('users').doc(uid);
  }

  @override
  Stream<AddressBook> watch() {
    final user = _userRef;
    return Stream.multi((controller) {
      List<SavedAddress>? rows;
      String? defaultId;
      var profileReady = false;
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

  @override
  Future<void> save(SavedAddress address, {bool makeDefault = false}) async {
    final data = address.toData();
    for (final field in ['label', 'addressLine1', 'city', 'state']) {
      if (addressRequired(data[field] as String) != null) {
        throw ArgumentError('Complete the address details.');
      }
    }
    final error =
        profileNameError(address.name) ??
        addressPhoneError(address.phone) ??
        addressPostalError(address.postalCode);
    if (error != null) throw ArgumentError(error);
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
