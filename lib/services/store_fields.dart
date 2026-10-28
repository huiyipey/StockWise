import '../models/app_models.dart';

typedef StoreCreator =
    Future<StoreInfo> Function({
      required String name,
      required String shopAddress,
    });

typedef StoreUpdater =
    Future<StoreInfo> Function({
      required String storeId,
      required String name,
      required String shopAddress,
    });

String? storeNameError(String? value) {
  final name = (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  if (name.length < 2) return 'Enter a store name of at least 2 characters';
  if (name.length > 80) return 'Use 80 characters or fewer';
  return null;
}

String? shopAddressError(String? value) {
  final address = (value ?? '').trim();
  if (address.isEmpty) return 'Enter the shop address';
  if (address.length > 500) return 'Use 500 characters or fewer';
  return null;
}
