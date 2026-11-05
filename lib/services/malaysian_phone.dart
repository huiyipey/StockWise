// Malaysian numbering patterns from Google's libphonenumber metadata, 2026-11-04.
// Source: https://github.com/google/libphonenumber/blob/master/resources/PhoneNumberMetadata.xml
// Copyright The Libphonenumber Authors. Apache-2.0; see
// assets/data/libphonenumber_LICENSE.txt. Keep the backend JSON in sync.

const malaysianPhonePatterns = <String, String>{
  'fixedLine':
      r'427[01]\d{4}|(?:3(?:2[0-36-9]|3[0-368]|4[0-278]|5[0-24-8]|6[0-467]|7[1246-9]|8\d|9[0-57])\d|4(?:2[0-689]|[3-79]\d|8[1-35689])|5(?:2[0-589]|[3468]\d|5[0-489]|7[1-9]|9[23])|6(?:2[2-9]|3[1357-9]|[46]\d|5[0-6]|7[0-35-9]|85|9[015-8])|7(?:[2579]\d|3[03-68]|4[0-8]|6[5-9]|8[0-35-9])|8(?:[24][2-8]|3[2-5]|5[2-7]|6[2-589]|7[2-578]|[89][2-9])|9(?:0[57]|13|[25-7]\d|[3489][0-8]))\d{5}',
  'mobile':
      r'1(?:(?:1888[689]|4400|8(?:47|8[27])[0-4])\d{4}|9\d{7,8})|1(?:0(?:[23568]\d|4[0-6]|7[016-9]|9[0-8])|1(?:[1-5]\d\d|6(?:0[5-9]|[1-9]\d)|7(?:[0-4]\d|5[0-79]|6[02-4]|8[02-5]))|(?:[26]\d|[37][1-9]|4[235-9])\d|5(?:31|9\d\d)|8(?:1[23]|[236]\d|4[06]|5(?:46|[7-9])|7[016-9]|8[01]|9[0-8]))\d{5}',
  'voip':
      r'15(?:4(?:6[0-4]\d|8(?:0[125]|[17]\d|21|3[01]|4[01589]|5[014]|6[02]))|6(?:32[0-6]|78\d))\d{4}',
  'tollFree': r'1[378]00\d{6}',
  'premiumRate': r'1600\d{6}',
};

final _nationalPattern = RegExp(
  '^(?:${malaysianPhonePatterns.values.join('|')})\$',
);
final _servicePattern = RegExp(
  '^(?:${malaysianPhonePatterns['tollFree']}|${malaysianPhonePatterns['premiumRate']})\$',
);
final _allowedCharacters = RegExp(r'^[+0-9 ()-]+$');
final _balancedParentheses = RegExp(
  r'^[^()]*(?:\([^()]*[0-9][^()]*\)[^()]*)*$',
);

/// Returns an E.164 equivalent for validation, without rewriting the user's input.
/// This checks Malaysia's number ranges and lengths, not ownership or reachability.
String? normalizeMalaysianPhone(String? value) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty ||
      raw.length > 64 ||
      !_allowedCharacters.hasMatch(raw) ||
      !_balancedParentheses.hasMatch(raw)) {
    return null;
  }
  final compact = raw.replaceAll(RegExp(r'[ ()-]'), '');
  if (!RegExp(r'^\+?[0-9]+$').hasMatch(compact)) return null;
  final String national;
  if (compact.startsWith('+60')) {
    national = compact.substring(3);
  } else if (compact.startsWith('0060')) {
    national = compact.substring(4);
  } else if (compact.startsWith('60')) {
    national = compact.substring(2);
  } else if (compact.startsWith('0')) {
    national = compact.substring(1);
  } else if (_servicePattern.hasMatch(compact)) {
    national = compact;
  } else {
    return null;
  }
  return _nationalPattern.hasMatch(national) ? '+60$national' : null;
}

bool isValidMalaysianPhone(String? value) =>
    normalizeMalaysianPhone(value) != null;

String? malaysianPhoneError(String? value, {bool isRequired = false}) {
  if ((value?.trim() ?? '').isEmpty) {
    return isRequired ? 'Enter a phone number' : null;
  }
  return isValidMalaysianPhone(value)
      ? null
      : 'Enter a valid Malaysian phone number';
}
