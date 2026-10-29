import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/email_verification_service.dart';
import '../services/firestore_service.dart';
import '../widgets/auth_ui.dart';
import 'email_verification_screen.dart';
import 'login_screen.dart';
import 'store_gate_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const AuthStatusScreen(
          title: 'Checking your session',
          message: 'StockWise is finding where you left off.',
        );
      }
      final user = snapshot.data;
      if (user == null) {
        return ValueListenableBuilder<String?>(
          valueListenable: verificationSignInEmail,
          builder: (_, email, _) => LoginScreen(
            key: ValueKey(email),
            initialEmail: email,
            verificationNotice: email != null,
          ),
        );
      }
      return AccountAccessGate(
        key: ValueKey(user.uid),
        canContinue: EmailVerificationService().canContinue,
        verifiedBuilder: (_) => const _ProfileGate(),
        verificationBuilder: (context, continueAfterVerification) =>
            EmailVerificationScreen(
              email: user.email ?? '',
              onContinue: continueAfterVerification,
            ),
      );
    },
  );
}

/// One gate owns entry after signup, sign-in and a restored session.
class AccountAccessGate extends StatefulWidget {
  const AccountAccessGate({
    super.key,
    required this.canContinue,
    required this.verifiedBuilder,
    required this.verificationBuilder,
  });
  final Future<bool> Function() canContinue;
  final WidgetBuilder verifiedBuilder;
  final Widget Function(BuildContext, VoidCallback) verificationBuilder;
  @override
  State<AccountAccessGate> createState() => _AccountAccessGateState();
}

class _AccountAccessGateState extends State<AccountAccessGate> {
  late Future<bool> _access;
  @override
  void initState() {
    super.initState();
    _access = widget.canContinue();
  }

  void _refresh() => setState(() {
    _access = widget.canContinue();
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _access,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const AuthStatusScreen(
          title: 'Checking your session',
          message: 'StockWise is checking your account access.',
        );
      }
      if (snapshot.hasError) {
        return AuthPage(
          child: AuthCard(
            title: 'Could not check account',
            subtitle: 'Check your connection and try again.',
            children: [
              AuthButton(
                label: 'Try again',
                busyLabel: 'Checking...',
                onPressed: _refresh,
              ),
              TextButton(
                onPressed: () => FirebaseAuth.instance.signOut(),
                child: const Text('Back to sign in'),
              ),
            ],
          ),
        );
      }
      return snapshot.data == true
          ? widget.verifiedBuilder(context)
          : widget.verificationBuilder(context, _refresh);
    },
  );
}

class _ProfileGate extends StatefulWidget {
  const _ProfileGate();
  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  late final _profile = FirestoreService.instance.ensureUserProfile();
  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _profile,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const AuthStatusScreen(
          title: 'Getting your account ready',
          message: 'You will continue to your stores automatically.',
        );
      }
      if (snapshot.hasError) {
        return const AuthStatusScreen(
          title: 'Could not load account',
          message:
              'Your account details could not be loaded. Please try opening the app again.',
          error: true,
        );
      }
      return const StoreGateScreen();
    },
  );
}
