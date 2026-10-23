import 'package:cloud_firestore/cloud_firestore.dart';

class SavedAddress {
  final String id;
  final String label;
  final String name;
  final String phone;
  final String addressLine1;
  final String city;
  final String state;
  final String postalCode;

  const SavedAddress({
    this.id = '',
    required this.label,
    required this.name,
    required this.phone,
    required this.addressLine1,
    required this.city,
    required this.state,
    required this.postalCode,
  });

  factory SavedAddress.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return SavedAddress(
      id: doc.id,
      label: data['label'] as String? ?? 'Address',
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      addressLine1: data['addressLine1'] as String? ?? '',
      city: data['city'] as String? ?? '',
      state: data['state'] as String? ?? '',
      postalCode: data['postalCode'] as String? ?? '',
    );
  }

  Map<String, dynamic> toData() => {
    'label': label.trim(),
    'name': name.trim(),
    'phone': phone.trim(),
    'addressLine1': addressLine1.trim(),
    'city': city.trim(),
    'state': state.trim(),
    'postalCode': postalCode.trim(),
    'countryCode': 'MY',
  };

  String get formatted => '$addressLine1, $postalCode $city, $state';
}

class AddressBook {
  final List<SavedAddress> addresses;
  final String? defaultAddressId;
  const AddressBook({this.addresses = const [], this.defaultAddressId});

  SavedAddress? get defaultAddress {
    for (final address in addresses) {
      if (address.id == defaultAddressId) return address;
    }
    return addresses.firstOrNull;
  }

  SavedAddress? find(String? id) =>
      addresses.where((a) => a.id == id).firstOrNull;
}
