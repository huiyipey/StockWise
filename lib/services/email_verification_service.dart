import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

const legacyAccountClaim = 'stockwise_legacy_account';
final verificationSignInEmail = ValueNotifier<String?>(null);

bool accountCanContinue({
  required bool verified,
  required Map<String, dynamic> claims,
}) => verified || claims[legacyAccountClaim] == true;

class VerificationStatus {
  const VerificationStatus({
    required this.email,
    this.verified = false,
    this.attempted = false,
    this.deliveryFailed = false,
    this.resendAfter = 0,
  });
  final String email;
  final bool verified, attempted, deliveryFailed;
  final int resendAfter;

  factory VerificationStatus.fromData(dynamic data) {
    if (data is! Map ||
        data['email'] is! String ||
        data['verified'] is! bool ||
        data['attempted'] is! bool ||
        data['deliveryFailed'] is! bool ||
        data['resendAfter'] is! num) {
      throw const VerificationFailure(
        'Could not load verification. Please try again.',
      );
    }
    return VerificationStatus(
      email: data['email'] as String,
      verified: data['verified'] as bool,
      attempted: data['attempted'] as bool,
      deliveryFailed: data['deliveryFailed'] as bool,
      resendAfter: (data['resendAfter'] as num).toInt().clamp(0, 3600),
    );
  }
}

class VerificationFailure implements Exception {
  const VerificationFailure(
    this.message, {
    this.retryAfter = 0,
    this.emailInvalid = false,
    this.reauthenticate = false,
  });
  final String message;
  final int retryAfter;
  final bool emailInvalid, reauthenticate;
}

abstract class EmailVerificationClient {
  Future<VerificationStatus> load();
  Future<VerificationStatus> send({String? newEmail});
  Future<VerificationStatus> check();
  Future<void> reauthenticate(String password);
  Future<void> signOut();
}

class EmailVerificationService implements EmailVerificationClient {
  EmailVerificationService({FirebaseAuth? auth, FirebaseFunctions? functions})
    : _auth = auth ?? FirebaseAuth.instance,
      _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  String? _pendingEmail;

  Future<bool> canContinue() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final current = _auth.currentUser;
    if (current == null || current.uid != user.uid) return false;
    final token = await current.getIdTokenResult(true);
    return accountCanContinue(
      verified: current.emailVerified,
      claims: token.claims ?? {},
    );
  }

  Future<VerificationStatus> _call(String action, {String? email}) async {
    final sessionUid = _auth.currentUser?.uid;
    try {
      final result = await _functions
          .httpsCallable(
            'manageEmailVerification',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 40)),
          )
          .call<dynamic>({'action': action, 'email': ?email});
      final status = VerificationStatus.fromData(result.data);
      _pendingEmail = status.email;
      final data = result.data;
      if (action == 'change' && data is Map && data['signInToken'] is String) {
        try {
          final credential = await _auth.signInWithCustomToken(
            data['signInToken'] as String,
          );
          if (sessionUid == null || credential.user?.uid != sessionUid) {
            await _auth.signOut();
            throw const VerificationFailure(
              'Please sign in again to continue.',
            );
          }
        } catch (_) {
          verificationSignInEmail.value = status.email;
          await _auth.signOut();
          throw const VerificationFailure(
            'Your signup email was updated. Please sign in again to continue.',
          );
        }
        try {
          return await _call('send');
        } catch (failure) {
          // The new address is already saved. Preserve it even if delivery fails.
          return VerificationStatus(
            email: status.email,
            attempted: true,
            deliveryFailed: true,
            resendAfter: failure is VerificationFailure
                ? failure.retryAfter
                : 0,
          );
        }
      }
      return status;
    } on FirebaseFunctionsException catch (error) {
      final details = error.details is Map ? error.details as Map : const {};
      throw VerificationFailure(
        switch (error.code) {
          'already-exists' => 'An account already uses this email.',
          'invalid-argument' => 'Enter a valid email address.',
          'resource-exhausted' =>
            details['reason'] == 'cooldown'
                ? 'Please wait before requesting another email.'
                : 'Too many requests. Please try again later.',
          'unauthenticated' => 'Your session expired. Please sign in again.',
          'failed-precondition' =>
            'Please confirm your password to change your email.',
          _ =>
            action == 'status'
                ? 'Could not check verification. Check your connection and try again.'
                : 'Could not send the email. Please try again.',
        },
        retryAfter: details['retryAfter'] is num
            ? (details['retryAfter'] as num).toInt().clamp(0, 3600)
            : 0,
        emailInvalid: details['field'] == 'email',
        reauthenticate: details['reason'] == 'requires-recent-login',
      );
    }
  }

  @override
  Future<VerificationStatus> load() => _call('status');

  @override
  Future<VerificationStatus> send({String? newEmail}) =>
      _call(newEmail == null ? 'send' : 'change', email: newEmail);

  @override
  Future<VerificationStatus> check() async {
    final user = _auth.currentUser;
    if (user == null) {
      verificationSignInEmail.value = _pendingEmail;
      throw const VerificationFailure(
        'Your session expired. Please sign in again.',
      );
    }
    try {
      await user.reload();
      final current = _auth.currentUser;
      if (current == null) {
        verificationSignInEmail.value = _pendingEmail ?? user.email;
        throw const VerificationFailure('Please sign in again to continue.');
      }
      if (current.uid != user.uid) {
        throw const VerificationFailure('Please sign in again.');
      }
      await current.getIdToken(true);
      return await _call('status');
    } on FirebaseAuthException catch (error) {
      if (const [
        'user-token-expired',
        'invalid-user-token',
        'requires-recent-login',
      ].contains(error.code)) {
        verificationSignInEmail.value = _pendingEmail ?? user.email;
        await _auth.signOut();
        throw const VerificationFailure('Please sign in again to continue.');
      }
      rethrow;
    }
  }

  @override
  Future<void> reauthenticate(String password) async {
    final user = _auth.currentUser;
    if (user?.email == null) {
      throw const VerificationFailure('Please sign in again.');
    }
    try {
      await user!.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: password),
      );
    } on FirebaseAuthException catch (error) {
      throw VerificationFailure(
        error.code == 'network-request-failed'
            ? 'Could not connect. Please try again.'
            : 'Could not confirm your password. Please try again.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    verificationSignInEmail.value = null;
    await _auth.signOut();
  }
}
