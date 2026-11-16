import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/account_registration_service.dart';
import '../services/email_verification_service.dart';
import '../services/store_session.dart';
import '../widgets/auth_ui.dart';
import 'signup_screen.dart';

// Validate the account email and handle sign-in or password reset.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.onSignIn,
    this.onResetPassword,
    this.onSignedIn,
    this.onEmailRegistered,
    this.initialEmail,
    this.verificationNotice = false,
  });
  final Future<void> Function(String email, String password)? onSignIn;
  final Future<void> Function(String email)? onResetPassword;
  final VoidCallback? onSignedIn;
  final RegisteredEmailChecker? onEmailRegistered;
  final String? initialEmail;
  final bool verificationNotice;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

// Manage the login screen values and actions.
class _LoginScreenState extends State<LoginScreen> {
  // Keep this component's values, selections, and request state.
  late final _email = TextEditingController(text: widget.initialEmail);
  final _password = TextEditingController();
  String? _error;
  bool _emailInvalid = false, _passwordInvalid = false;
  bool _signingIn = false, _sendingReset = false, _resetSent = false;
  bool _passwordVisible = false;
  // Check whether an account request is already running.
  bool get _busy => _signingIn || _sendingReset;

  // Clear old errors when the form is edited.
  void _clearFeedback(String _) => setState(() {
    _error = null;
    _emailInvalid = _passwordInvalid = _resetSent = false;
  });

  // Show the message beside the relevant form field.
  void _showError(
    String message, {
    bool email = false,
    bool password = false,
  }) => setState(() {
    _error = message;
    _emailInvalid = email;
    _passwordInvalid = password;
    _resetSent = false;
  });

  // Check the email format before contacting Firebase.
  bool _validEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

  // Reject an email that is not registered.
  Future<bool> _checkRegisteredEmail(String email) async {
    try {
      final registered =
          await (widget.onEmailRegistered ??
              AccountRegistrationService.instance.isRegistered)(email);
      if (!mounted) return false;
      if (!registered) {
        _showError(
          'This email is not registered. Please create an account.',
          email: true,
        );
      }
      return registered;
    } on EmailLookupFailure catch (failure) {
      if (mounted) _showError(failure.message);
    } catch (_) {
      if (mounted) {
        _showError('Unable to check this email. Please try again.');
      }
    }
    return false;
  }

  // Convert Firebase account errors to readable messages.
  void _authError(FirebaseAuthException failure, {bool reset = false}) {
    switch (failure.code) {
      case 'invalid-email':
        _showError('Enter a valid email address.', email: true);
      case 'user-disabled':
        _showError('This account has been disabled.');
      case 'too-many-requests':
        _showError('Too many attempts. Please try again later.');
      case 'invalid-credential':
      case 'invalid-login-credentials':
      case 'wrong-password':
        _showError(
          reset
              ? 'Unable to send reset email. Please try again.'
              : 'Invalid email or password.',
          email: !reset,
          password: !reset,
        );
      case 'user-not-found':
        _showError(
          'This email is not registered. Please create an account.',
          email: true,
        );
      default:
        _showError(
          reset
              ? 'Unable to send reset email. Please try again.'
              : 'Unable to sign in. Please try again.',
        );
    }
  }

  // Validate the credentials and sign in.
  Future<void> _login() async {
    if (_busy) return;
    final email = _email.text.trim(), password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      _showError(
        'Enter your email and password.',
        email: email.isEmpty,
        password: password.isEmpty,
      );
      return;
    }
    if (!_validEmail(email)) {
      _showError('Enter a valid email address.', email: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _signingIn = true;
      _error = null;
      _emailInvalid = _passwordInvalid = _resetSent = false;
    });
    try {
      if (!await _checkRegisteredEmail(email)) return;
      if (widget.onSignIn != null) {
        await widget.onSignIn!(email, password);
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      StoreSession.instance.clear();
      verificationSignInEmail.value = null;
      TextInput.finishAutofillContext();
      if (!mounted) return;
      if (widget.onSignedIn != null) {
        widget.onSignedIn!();
      } else {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } on FirebaseAuthException catch (failure) {
      if (mounted) _authError(failure);
    } catch (_) {
      if (mounted) _showError('Unable to sign in. Please try again.');
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  // Check the account before sending a password reset email.
  Future<void> _resetPassword() async {
    if (_busy) return;
    final email = _email.text.trim();
    if (email.isEmpty) {
      _showError('Enter your email first.', email: true);
      return;
    }
    if (!_validEmail(email)) {
      _showError('Enter a valid email address.', email: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _sendingReset = true;
      _error = null;
      _emailInvalid = _passwordInvalid = _resetSent = false;
    });
    try {
      if (!await _checkRegisteredEmail(email)) return;
      if (widget.onResetPassword != null) {
        await widget.onResetPassword!(email);
      } else {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      }
      if (mounted) setState(() => _resetSent = true);
    } on FirebaseAuthException catch (failure) {
      if (mounted) _authError(failure, reset: true);
    } catch (_) {
      if (mounted) _showError('Unable to send reset email. Please try again.');
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }

  // Release controllers, timers, and subscriptions held by this component.
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  // Build the login screen layout.
  @override
  Widget build(BuildContext context) => AuthPage(
    footer: AuthAccountLink(
      prompt: 'New to StockWise?',
      label: 'Create an account',
      onPressed: _busy
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SignupScreen()),
            ),
    ),
    child: AutofillGroup(
      // Group the authentication form and its heading.
      child: AuthCard(
        title: 'Welcome Back',
        subtitle: 'Sign in to continue to your store.',
        children: [
          // Enter the email.
          AuthField(
            key: const ValueKey('login-email'),
            controller: _email,
            label: 'Email',
            hint: 'you@example.com',
            invalid: _emailInvalid,
            enabled: !_busy,
            autofillHints: const [AutofillHints.username],
            onChanged: _clearFeedback,
          ),
          const SizedBox(height: 20),
          // Enter the password.
          AuthField(
            key: const ValueKey('login-password'),
            controller: _password,
            label: 'Password',
            hint: 'Enter your password',
            password: true,
            visible: _passwordVisible,
            invalid: _passwordInvalid,
            enabled: !_busy,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _login(),
            onChanged: _clearFeedback,
            onToggleVisibility: () =>
                setState(() => _passwordVisible = !_passwordVisible),
          ),
          const SizedBox(height: 12),
          if (_resetSent)
            // Show confirmation that a reset email was sent.
            const AuthResetConfirmation()
          else if (_error == null && widget.verificationNotice)
            Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AuthColors.soft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Text(
                  'Please sign in again to continue with this email address.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: AuthColors.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else
            // Show the form error beside the relevant input.
            AuthError(_error),
          if (_resetSent) const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy ? null : _resetPassword,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                minimumSize: const Size(48, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: AuthColors.green,
                textStyle: const TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_sendingReset) ...[
                    const SizedBox.square(
                      dimension: 13,
                      child: CircularProgressIndicator(
                        color: AuthColors.green,
                        strokeWidth: 1.5,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    _sendingReset
                        ? 'Sending reset email...'
                        : 'Forgot password?',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Show the form action with its loading state.
          AuthButton(
            label: 'Sign in',
            busyLabel: 'Signing in...',
            busy: _signingIn,
            onPressed: _busy ? null : _login,
          ),
        ],
      ),
    ),
  );
}
