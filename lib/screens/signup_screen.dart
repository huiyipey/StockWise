import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/password_policy.dart';
import '../widgets/auth_ui.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, this.onCreateAccount, this.onAccountCreated});
  final Future<void> Function(String email, String password)? onCreateAccount;
  final VoidCallback? onAccountCreated;
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  String? _error;
  final _invalid = <String>{};
  bool _creating = false,
      _passwordVisible = false,
      _confirmationVisible = false,
      _confirmingLeave = false,
      _allowExit = false;

  bool get _hasUnsavedInformation =>
      _email.text.isNotEmpty ||
      _password.text.isNotEmpty ||
      _confirmation.text.isNotEmpty;

  Future<void> _requestLeave() async {
    if (_creating || _confirmingLeave || _allowExit) return;
    if (!_hasUnsavedInformation) {
      Navigator.pop(context);
      return;
    }
    _confirmingLeave = true;
    FocusScope.of(context).unfocus();
    try {
      final discard = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          title: const Text(
            'Discard signup information?',
            style: TextStyle(
              color: AuthColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            "You haven't created an account yet. If you leave now, the information you've entered will be discarded.",
            style: TextStyle(
              color: AuthColors.muted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  style: FilledButton.styleFrom(
                    backgroundColor: AuthColors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Keep editing'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: TextButton.styleFrom(
                    foregroundColor: AuthColors.error,
                  ),
                  child: const Text('Discard and leave'),
                ),
              ],
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
      setState(() => _allowExit = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pop(context);
      }
    } finally {
      _confirmingLeave = false;
    }
  }

  void _clearFeedback(String _) => setState(() {
    _error = null;
    _invalid.clear();
  });
  void _showError(String message, [Set<String> fields = const {}]) =>
      setState(() {
        _error = message;
        _invalid
          ..clear()
          ..addAll(fields);
      });
  void _authError(FirebaseAuthException failure) {
    switch (failure.code) {
      case 'invalid-email':
        _showError('Enter a valid email address.', {'email'});
      case 'weak-password':
      case 'password-does-not-meet-requirements':
        _showError('Your password does not meet the requirements.', {
          'password',
        });
      case 'email-already-in-use':
        _showError('An account already uses this email.', {'email'});
      case 'too-many-requests':
        _showError('Too many attempts. Please try again later.');
      case 'network-request-failed':
        _showError('Could not connect. Please try again.');
      default:
        _showError(
          'Account creation is currently unavailable. Please try again later.',
        );
    }
  }

  Future<void> _register() async {
    if (_creating || _confirmingLeave || _allowExit) return;
    final email = _email.text.trim(), password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      _showError('Enter your email and password.', {
        if (email.isEmpty) 'email',
        if (password.isEmpty) 'password',
      });
      return;
    }
    if (_confirmation.text.isEmpty) {
      _showError('Please confirm your password.', {'confirmation'});
      return;
    }
    if (password != _confirmation.text) {
      _showError('Passwords do not match.', {'confirmation'});
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _showError('Enter a valid email address.', {'email'});
      return;
    }
    final passwordError = passwordPolicyError(password);
    if (passwordError != null) {
      _showError(passwordError, {'password'});
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _creating = true;
      _error = null;
      _invalid.clear();
    });
    try {
      if (widget.onCreateAccount != null) {
        await widget.onCreateAccount!(email, password);
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      TextInput.finishAutofillContext();
      if (!mounted) return;
      setState(() {
        _allowExit = true;
        _creating = false;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      if (widget.onAccountCreated != null) {
        widget.onAccountCreated!();
      } else {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } on FirebaseAuthException catch (failure) {
      if (mounted) _authError(failure);
    } catch (_) {
      if (mounted) {
        _showError('Could not create your account. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_creating && (_allowExit || !_hasUnsavedInformation),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) unawaited(_requestLeave());
    },
    child: AuthPage(
      footer: AuthAccountLink(
        prompt: 'Already have an account?',
        label: 'Sign in',
        onPressed: _creating ? null : _requestLeave,
      ),
      child: AutofillGroup(
        onDisposeAction: AutofillContextAction.cancel,
        child: AuthCard(
          title: 'Create account',
          subtitle: 'Start with your email and password.',
          children: [
            AuthField(
              key: const ValueKey('signup-email'),
              controller: _email,
              label: 'Email',
              hint: 'you@example.com',
              invalid: _invalid.contains('email'),
              enabled: !_creating,
              autofillHints: const [AutofillHints.newUsername],
              onChanged: _clearFeedback,
            ),
            const SizedBox(height: 20),
            AuthField(
              key: const ValueKey('signup-password'),
              controller: _password,
              label: 'Password',
              hint: 'Create a password',
              password: true,
              visible: _passwordVisible,
              invalid: _invalid.contains('password'),
              enabled: !_creating,
              autofillHints: const [AutofillHints.newPassword],
              onChanged: _clearFeedback,
              onToggleVisibility: () =>
                  setState(() => _passwordVisible = !_passwordVisible),
            ),
            const SizedBox(height: 8),
            const Text(
              passwordRequirements,
              style: TextStyle(
                color: AuthColors.muted,
                fontSize: 11,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            AuthField(
              key: const ValueKey('signup-confirmation'),
              controller: _confirmation,
              label: 'Confirm password',
              hint: 'Re-enter your password',
              password: true,
              visible: _confirmationVisible,
              invalid: _invalid.contains('confirmation'),
              enabled: !_creating,
              autofillHints: const [AutofillHints.newPassword],
              onChanged: _clearFeedback,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _register(),
              onToggleVisibility: () =>
                  setState(() => _confirmationVisible = !_confirmationVisible),
            ),
            const SizedBox(height: 12),
            AuthError(_error),
            const SizedBox(height: 8),
            const Text(
              "We'll email you a link to verify your account.",
              style: TextStyle(
                color: AuthColors.muted,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            AuthButton(
              label: 'Create account',
              busyLabel: 'Creating account...',
              busy: _creating,
              onPressed: _register,
            ),
          ],
        ),
      ),
    ),
  );
}
