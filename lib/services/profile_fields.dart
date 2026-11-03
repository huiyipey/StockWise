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

// Malaysian national numbers, or the equivalent +60 / 0060 form.
// Checks format only; no SMS or ownership verification is performed.
String? profilePhoneError(String? value) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) return null;
  if (!RegExp(r'^\+?[0-9 ()-]+$').hasMatch(raw)) {
    return 'Enter a valid Malaysian phone number';
  }
  var digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');
  if (digits.startsWith('+60')) {
    digits = '0${digits.substring(3)}';
  } else if (digits.startsWith('0060')) {
    digits = '0${digits.substring(4)}';
  } else if (digits.startsWith('60')) {
    digits = '0${digits.substring(2)}';
  }
  final mobile = RegExp(r'^01(?:[15]\d{8}|[02-46-9]\d{7})$');
  final fixed = RegExp(r'^0(?:3\d{8}|[4-79]\d{7}|8[2-9]\d{6})$');
  return mobile.hasMatch(digits) || fixed.hasMatch(digits)
      ? null
      : 'Enter a valid Malaysian phone number';
}
