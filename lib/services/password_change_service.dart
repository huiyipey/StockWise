import 'package:firebase_auth/firebase_auth.dart';
import 'password_policy.dart';

typedef PasswordChanger =
    Future<void> Function({
      required String currentPassword,
      required String newPassword,
    });

String? currentPasswordError(String? value) =>
    value == null || value.isEmpty ? 'Enter your current password' : null;

String? newPasswordError(String? value, String currentPassword) {
  if (value == null || value.isEmpty) return 'Enter a new password';
  if (value == currentPassword) return 'Choose a different password';
  return passwordPolicyError(value);
}

String? confirmPasswordError(String? value, String newPassword) {
  if (value == null || value.isEmpty) return 'Confirm your new password';
  if (value != newPassword) return 'Passwords do not match';
  return null;
}

class PasswordChangeFailure implements Exception {
  final String message;
  const PasswordChangeFailure(this.message);
}

abstract class PasswordAccount {
  bool get supportsPassword;
  Future<void> verifyCurrentPassword(String password);
  Future<void> updatePassword(String password);
}

class _FirebasePasswordAccount implements PasswordAccount {
  final FirebaseAuth auth;
  final User user;
  _FirebasePasswordAccount(this.auth, this.user);

  @override
  bool get supportsPassword =>
      user.email != null &&
      user.providerData.any((provider) => provider.providerId == 'password');

  @override
  Future<void> verifyCurrentPassword(String password) async {
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: user.email!, password: password),
    );
  }

  @override
  Future<void> updatePassword(String password) async {
    if (auth.currentUser?.uid != user.uid) {
      throw const PasswordChangeFailure(
        'Your session changed. Please sign in again.',
      );
    }
    await user.updatePassword(password);
  }
}

class PasswordChangeService {
  final PasswordAccount? _account;
  PasswordChangeService([this._account]);
  static final instance = PasswordChangeService();

  Future<void> change({
    required String currentPassword,
    required String newPassword,
  }) async {
    final validation =
        currentPasswordError(currentPassword) ??
        newPasswordError(newPassword, currentPassword);
    if (validation != null) throw PasswordChangeFailure(validation);
    try {
      final PasswordAccount account;
      if (_account != null) {
        account = _account;
      } else {
        final auth = FirebaseAuth.instance;
        final user = auth.currentUser;
        if (user == null) {
          throw const PasswordChangeFailure(
            'Please sign in again to change your password.',
          );
        }
        account = _FirebasePasswordAccount(auth, user);
      }
      if (!account.supportsPassword) {
        throw const PasswordChangeFailure(
          'This account does not use an email and password. Manage your password with your sign-in provider.',
        );
      }
      // Firebase must verify the current password before changing credentials.
      await account.verifyCurrentPassword(currentPassword);
      await account.updatePassword(newPassword);
    } on FirebaseAuthException catch (error) {
      throw PasswordChangeFailure(switch (error.code) {
        'wrong-password' ||
        'invalid-credential' ||
        'invalid-login-credentials' ||
        'user-mismatch' => 'Your current password is incorrect.',
        'weak-password' || 'password-does-not-meet-requirements' =>
          'Choose a stronger password that meets your account’s password requirements.',
        'too-many-requests' => 'Too many attempts. Please try again later.',
        'network-request-failed' =>
          'Check your internet connection and try again.',
        'requires-recent-login' ||
        'user-token-expired' ||
        'invalid-user-token' =>
          'Please sign in again and retry changing your password.',
        'user-disabled' || 'user-not-found' =>
          'This account is unavailable. Please sign in again.',
        _ => 'Could not change your password. Please try again.',
      });
    } on PasswordChangeFailure {
      rethrow;
    } catch (_) {
      throw const PasswordChangeFailure(
        'Could not change your password. Please try again.',
      );
    }
  }
}
