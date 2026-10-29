import 'package:cloud_functions/cloud_functions.dart';

typedef RegisteredEmailChecker = Future<bool> Function(String email);

class EmailLookupFailure implements Exception {
  const EmailLookupFailure(this.message);
  final String message;
}

class AccountRegistrationService {
  AccountRegistrationService._();
  static final instance = AccountRegistrationService._();

  Future<bool> isRegistered(String email) async {
    try {
      final result =
          await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
              .httpsCallable(
                'checkRegisteredEmail',
                options: HttpsCallableOptions(
                  timeout: const Duration(seconds: 15),
                ),
              )
          .call({'email': email});
      final data = result.data;
      final registered = data is Map ? data['registered'] : null;
      if (registered is! bool) {
        throw const EmailLookupFailure(
          'Unable to check this email. Please try again.',
        );
      }
      return registered;
    } on FirebaseFunctionsException catch (failure) {
      throw EmailLookupFailure(
        failure.code == 'resource-exhausted'
            ? 'Too many attempts. Please try again later.'
            : 'Unable to check this email. Please try again.',
      );
    } on EmailLookupFailure {
      rethrow;
    } catch (_) {
      throw const EmailLookupFailure(
        'Unable to check this email. Please try again.',
      );
    }
  }
}
