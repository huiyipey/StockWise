import 'package:image_picker/image_picker.dart';
import 'malaysian_phone.dart';

typedef ProfileSaver =
    Future<void> Function({
      required String displayName,
      required String phoneNumber,
      XFile? photo,
    });

String? profileNameError(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) return 'Enter your name';
  if (name.length > 80) return 'Use 80 characters or fewer';
  return null;
}

// Optional in Profile; address-book and checkout forms also require a value.
String? profilePhoneError(String? value) => malaysianPhoneError(value);
