import '../models/app_models.dart';
import '../models/store_address.dart';

typedef StoreCreator =
    Future<StoreInfo> Function({
      required String name,
      required StoreAddress address,
    });

typedef StoreUpdater =
    Future<StoreInfo> Function({
      required String storeId,
      required String name,
      required StoreAddress address,
    });

// Validate the shop name length and required value.
String? storeNameError(String? value) {
  final name = (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  if (name.length < 2) return 'Enter a store name of at least 2 characters';
  if (name.length > 80) return 'Use 80 characters or fewer';
  return null;
}

// Validate the required shop address.
String? shopAddressError(String? value) {
  final address = (value ?? '').trim();
  if (address.isEmpty) return 'Enter the shop address';
  if (address.length > 500) return 'Use 500 characters or fewer';
  return null;
}

// Validate a required address line.
String? addressLineError(String? value, {bool required = true}) {
  final line = (value ?? '').trim();
  if (required && line.isEmpty) return 'Enter Address 1';
  if (line.length > 200) return 'Use 200 characters or fewer';
  return null;
}

// Require a valid Malaysian postcode.
String? postcodeError(String? value) => RegExp(r'^\d{5}$').hasMatch(value ?? '')
    ? null
    : 'Enter a 5-digit postcode';

// Require a city within the supported length.
String? cityError(String? value) {
  if ((value ?? '').trim().isEmpty) return 'Enter the city';
  if (value!.trim().length > 80) return 'Use 80 characters or fewer';
  if (RegExp(r'[\r\n]').hasMatch(value)) return 'Enter the city on one line';
  return null;
}
