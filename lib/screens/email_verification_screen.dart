import 'dart:async';

import 'package:flutter/material.dart';

import '../services/email_verification_service.dart';
import '../services/store_session.dart';
import '../widgets/auth_ui.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.onContinue,
    this.client,
  });
  final String email;
  final VoidCallback onContinue;
  final EmailVerificationClient? client;
  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with WidgetsBindingObserver {
  late final EmailVerificationClient _client;
  late String _email;
  bool _loading = true,
      _sending = false,
      _checking = false,
      _signingOut = false;
  bool _verified = false,
      _resent = false,
      _sendFailed = false,
      _loadFailed = false,
      _editing = false;
  bool _resumeCheckPending = false, _continuing = false;
  int _remaining = 0;
  String? _error;
  Timer? _timer;
  bool get _busy =>
      _loading ||
      _sending ||
      _checking ||
      _signingOut ||
      _editing ||
      _continuing;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? EmailVerificationService();
    _email = widget.email;
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_verified && !_signingOut) {
      _resumeCheckPending = true;
      _checkAfterResume();
    }
  }

  void _checkAfterResume() {
    if (!mounted || _verified || _continuing) {
      _resumeCheckPending = false;
      return;
    }
    if (_resumeCheckPending && !_busy) {
      _resumeCheckPending = false;
      unawaited(_check(manual: false));
    }
  }

  void _cooldown(int seconds) {
    _timer?.cancel();
    _remaining = seconds;
    if (seconds > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return timer.cancel();
        setState(() => _remaining = (_remaining - 1).clamp(0, 3600));
        if (_remaining == 0) timer.cancel();
      });
    }
  }

  void _apply(VerificationStatus status) {
    _email = status.email;
    _verified = status.verified;
    _sendFailed = status.deliveryFailed;
    _loadFailed = false;
    _cooldown(status.resendAfter);
    if (_verified && !_continuing) {
      _continuing = true;
      _resumeCheckPending = false;
      _timer?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onContinue();
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
      _error = null;
    });
    var sendFirstEmail = false;
    try {
      final status = await _client.load();
      if (!mounted) return;
      setState(() {
        _apply(status);
        sendFirstEmail = !status.attempted && !status.verified;
        if (status.deliveryFailed) {
          _error = 'Could not send the email. Please try again.';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadFailed = true;
          _error =
              'Could not load verification. Check your connection and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    if (mounted && sendFirstEmail) await _send(initial: true);
    _checkAfterResume();
  }

  void _failure(Object failure, String fallback) {
    if (failure is VerificationFailure) {
      _error = failure.message;
      if (failure.retryAfter > 0) _cooldown(failure.retryAfter);
    } else {
      _error = fallback;
    }
  }

  Future<void> _send({bool initial = false}) async {
    if (_busy || _remaining > 0 || _verified) return;
    setState(() {
      _sending = true;
      _error = null;
      _resent = false;
    });
    try {
      final status = await _client.send();
      if (mounted) {
        setState(() {
          _apply(status);
          _resent = !initial && !status.verified;
        });
      }
    } catch (failure) {
      if (mounted) {
        setState(() {
          _sendFailed = true;
          _failure(failure, 'Could not send the email. Please try again.');
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
      _checkAfterResume();
    }
  }

  Future<void> _check({bool manual = true}) async {
    if (_busy || _verified) return;
    setState(() {
      _checking = true;
      _error = null;
      _resent = false;
    });
    try {
      final status = await _client.check();
      if (mounted) {
        setState(() {
          _apply(status);
          if (!status.verified && manual) {
            _error =
                'Your email is not verified yet. Complete verification from the email link, then try again.';
          }
        });
      }
    } catch (failure) {
      if (mounted) {
        setState(
          () => _failure(
            failure,
            'Could not check verification. Check your connection and try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
      _checkAfterResume();
    }
  }

  Future<void> _signOut() async {
    if (_busy) return;
    _resumeCheckPending = false;
    setState(() => _signingOut = true);
    try {
      await _client.signOut();
      StoreSession.instance.clear();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not sign out. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  Future<void> _editEmail() async {
    if (_busy || _verified) return;
    setState(() => _editing = true);
    final status = await showModalBottomSheet<VerificationStatus>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(27)),
      ),
      builder: (_) => _ChangeVerificationEmail(client: _client, email: _email),
    );
    if (!mounted) return;
    setState(() {
      _editing = false;
      if (status != null) {
        _apply(status);
        _resent = !status.verified && !status.deliveryFailed;
        _error = status.deliveryFailed
            ? 'Your signup email was updated, but the verification email could not be sent. Please try again.'
            : null;
      }
    });
    _checkAfterResume();
  }

  Widget _link(String label, VoidCallback? onPressed, {double size = 12.5}) =>
      TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: AuthColors.green,
          disabledForegroundColor: AuthColors.muted,
          minimumSize: const Size(48, 44),
          textStyle: TextStyle(
            fontSize: size,
            height: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Text(label, textAlign: TextAlign.center),
      );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final time =
        '${(_remaining ~/ 60).toString().padLeft(2, '0')}:${(_remaining % 60).toString().padLeft(2, '0')}';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _signOut();
      },
      child: AuthPage(
        footer: _verified
            ? null
            : _link(
                _signingOut ? 'Signing out...' : 'Back to sign in',
                _busy ? null : _signOut,
                size: 13,
              ),
        child: AuthCard(
          leading: Align(
            alignment: Alignment.centerLeft,
            child: CircleAvatar(
              radius: 27,
              backgroundColor: AuthColors.soft,
              child: Icon(
                _verified ? Icons.check : Icons.mail_outline,
                size: 28,
                color: AuthColors.green,
              ),
            ),
          ),
          title: _verified
              ? 'Email verified'
              : (_sendFailed ? 'Verify your email' : 'Check your email'),
          subtitle: _verified
              ? "You're all set. Welcome to StockWise."
              : 'One last step before you get started.',
          children: [
            if (!_verified) ...[
              const Text(
                'VERIFICATION EMAIL',
                style: TextStyle(
                  fontSize: 9.5,
                  color: AuthColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 16),
              decoration: BoxDecoration(
                color: AuthColors.background,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AuthColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.mail_outline,
                    color: AuthColors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _email,
                      style: const TextStyle(
                        fontSize: 12.8,
                        color: AuthColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            if (_verified) ...[
              const _VerificationNotice(title: 'Your email is confirmed.'),
              const SizedBox(height: 24),
              const Text(
                'Opening your stores...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AuthColors.muted),
              ),
            ] else ...[
              Text(
                _sendFailed
                    ? 'Your account was created. We could not send the verification email.'
                    : 'Open the email link, complete verification, then come back here to continue.',
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: AuthColors.muted,
                ),
              ),
              const SizedBox(height: 24),
              if (_resent) ...[
                const _VerificationNotice(
                  title: 'A new link is on its way.',
                  body: 'Check your inbox and spam folder.',
                ),
                const SizedBox(height: 20),
              ],
              if (_error != null) ...[
                AuthError(_error),
                const SizedBox(height: 20),
              ],
              AuthButton(
                label: _loadFailed
                    ? 'Try again'
                    : (_sendFailed
                          ? 'Send verification email'
                          : "I've verified my email"),
                busy: _loading || _sending || _checking,
                busyLabel: _loading
                    ? 'Loading...'
                    : (_sending ? 'Sending email...' : 'Checking...'),
                onPressed: _busy || (_sendFailed && _remaining > 0)
                    ? null
                    : (_loadFailed ? _load : (_sendFailed ? _send : _check)),
              ),
              const SizedBox(height: 14),
              _link(
                _sendFailed
                    ? "I've verified my email"
                    : _remaining > 0
                    ? 'Resend email in $time'
                    : 'Resend verification email',
                _busy
                    ? null
                    : (_sendFailed ? _check : (_remaining > 0 ? null : _send)),
              ),
              if (_sendFailed && _remaining > 0)
                Text(
                  'Try sending again in $time',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: AuthColors.muted),
                ),
              _link(
                'Wrong email address?',
                _busy ? null : _editEmail,
                size: 11.7,
              ),
              if (!_sendFailed && !_resent) ...[
                const SizedBox(height: 6),
                const Text(
                  'Check your spam folder too.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10.5, color: AuthColors.muted),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _VerificationNotice extends StatelessWidget {
  const _VerificationNotice({required this.title, this.body});
  final String title;
  final String? body;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AuthColors.soft,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check, size: 18, color: AuthColors.green),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AuthColors.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (body != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    body!,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: AuthColors.green,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ChangeVerificationEmail extends StatefulWidget {
  const _ChangeVerificationEmail({required this.client, required this.email});
  final EmailVerificationClient client;
  final String email;
  @override
  State<_ChangeVerificationEmail> createState() =>
      _ChangeVerificationEmailState();
}

class _ChangeVerificationEmailState extends State<_ChangeVerificationEmail> {
  late final _email = TextEditingController(text: widget.email);
  final _password = TextEditingController();
  bool _busy = false,
      _invalid = false,
      _reauthenticate = false,
      _visible = false;
  String? _error;
  Future<void> _save() async {
    if (_busy) return;
    final email = _email.text.trim();
    if (email.length > 254 ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() {
        _invalid = true;
        _error = 'Enter a valid email address.';
      });
      return;
    }
    if (_reauthenticate && _password.text.isEmpty) {
      setState(() => _error = 'Enter your password to continue.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _invalid = false;
    });
    try {
      if (_reauthenticate) await widget.client.reauthenticate(_password.text);
      final status = await widget.client.send(newEmail: email);
      if (mounted) Navigator.pop(context, status);
    } on VerificationFailure catch (failure) {
      if (mounted) {
        setState(() {
          _error = failure.message;
          _invalid = failure.emailInvalid;
          _reauthenticate = _reauthenticate || failure.reauthenticate;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not send the email. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 58,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AuthColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Change email',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AuthColors.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AuthColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                "We'll update your signup email and send a verification link to the new address.",
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: AuthColors.muted,
                ),
              ),
              const SizedBox(height: 26),
              AuthField(
                key: const ValueKey('verification-new-email'),
                controller: _email,
                label: 'Email',
                hint: 'you@example.com',
                invalid: _invalid,
                enabled: !_busy,
                onChanged: (_) => setState(() {
                  _error = null;
                  _invalid = false;
                }),
              ),
              const SizedBox(height: 12),
              AuthError(_error),
              if (_reauthenticate) ...[
                const SizedBox(height: 12),
                AuthField(
                  key: const ValueKey('verification-current-password'),
                  controller: _password,
                  label: 'Password',
                  hint: 'Enter your password',
                  password: true,
                  visible: _visible,
                  enabled: !_busy,
                  onToggleVisibility: () =>
                      setState(() => _visible = !_visible),
                ),
                const SizedBox(height: 16),
              ],
              const Text(
                'Your account will stay unverified until you open the new link.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.5,
                  color: AuthColors.muted,
                ),
              ),
              const SizedBox(height: 26),
              AuthButton(
                label: 'Save and resend',
                busyLabel: 'Sending email...',
                busy: _busy,
                onPressed: _save,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: AuthColors.green),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
