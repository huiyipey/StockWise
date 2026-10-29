const passwordRequirements =
    'Use 8+ characters with uppercase, lowercase, a number and a special character (e.g. ! @ #).';

// Matches Firebase's supported non-alphanumeric password-policy characters.
const _specialCharacters =
    r"""^$*.[]{}()?"!@#%&/\,><':;|_~"""
    '\u0060';

String? passwordPolicyError(String password) {
  if (password.length < 8) return 'Use at least 8 characters.';
  if (!RegExp(r'[A-Z]').hasMatch(password)) {
    return 'Add an uppercase letter (A-Z).';
  }
  if (!RegExp(r'[a-z]').hasMatch(password)) {
    return 'Add a lowercase letter (a-z).';
  }
  if (!RegExp(r'[0-9]').hasMatch(password)) {
    return 'Add a number (0-9).';
  }
  if (!password.split('').any(_specialCharacters.contains)) {
    return 'Add a special character, such as !, @ or #.';
  }
  return null;
}
