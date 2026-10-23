import 'package:image_picker/image_picker.dart';

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

String? profilePhoneError(String? value) {
  final phone = value?.trim() ?? '';
  if (phone.isEmpty) return null;
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (!RegExp(r'^\+?[0-9 ()-]+$').hasMatch(phone) ||
      digits.length < 7 ||
      digits.length > 15) {
    return 'Enter a valid phone number';
  }
  return null;
}
