import 'dart:ui' show SemanticsValidationResult;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The authentication palette is scoped to the approved entry-screen design.
abstract final class AuthColors {
  static const background = Color(0xFFF6F6F6);
  static const ink = Color(0xFF18382C);
  static const green = Color(0xFF247653);
  static const soft = Color(0xFFE1EBDD);
  static const muted = Color(0xFF64766A);
  static const border = Color(0xFFD1DAD0);
  static const error = Color(0xFFBB513D);
}

class AuthPage extends StatelessWidget {
  const AuthPage({super.key, required this.child, this.footer});
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AuthColors.background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AuthColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20, keyboardOpen ? 24 : 46, 20, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!keyboardOpen) ...[
                      const AuthBrand(),
                      const SizedBox(height: 48),
                    ],
                    child,
                    if (footer != null) ...[
                      const SizedBox(height: 24),
                      footer!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthBrand extends StatelessWidget {
  const AuthBrand({super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Image.asset(
        'assets/branding/auth_logo.png',
        width: 47,
        height: 47,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      ),
      const SizedBox(width: 12),
      const Flexible(
        child: Text(
          'StockWise',
          style: TextStyle(
            color: AuthColors.ink,
            fontSize: 26.5,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: -.3,
          ),
        ),
      ),
    ],
  );
}

class AuthCard extends StatelessWidget {
  const AuthCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.leading,
  });
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (leading != null) ...[leading!, const SizedBox(height: 20)],
          Text(
            title,
            style: const TextStyle(
              color: AuthColors.ink,
              fontSize: 29,
              height: 1.2,
              fontWeight: FontWeight.w700,
              letterSpacing: -.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: AuthColors.muted,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),
          ...children,
        ],
      ),
    ),
  );
}

class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.password = false,
    this.visible = false,
    this.invalid = false,
    this.enabled = true,
    this.onToggleVisibility,
    this.onChanged,
    this.onSubmitted,
    this.autofillHints,
    this.textInputAction = TextInputAction.next,
  });
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool password;
  final bool visible;
  final bool invalid;
  final bool enabled;
  final VoidCallback? onToggleVisibility;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(color: color, width: 1),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AuthColors.ink,
            fontSize: 12,
            height: 1.3,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Semantics(
            label: label,
            validationResult: invalid
                ? SemanticsValidationResult.invalid
                : SemanticsValidationResult.none,
            child: TextField(
              controller: controller,
              enabled: enabled,
              obscureText: password && !visible,
              autocorrect: false,
              enableSuggestions: !password,
              keyboardType: password
                  ? TextInputType.visiblePassword
                  : TextInputType.emailAddress,
              textInputAction: textInputAction,
              autofillHints: autofillHints,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              scrollPadding: const EdgeInsets.all(32),
              style: const TextStyle(
                color: AuthColors.ink,
                fontSize: 13.5,
                height: 1.4,
              ),
              decoration: InputDecoration(
                hintText: hint,
                semanticCounterText: invalid ? '$label needs attention' : null,
                hintStyle: const TextStyle(
                  color: AuthColors.muted,
                  fontSize: 13.5,
                  height: 1.4,
                ),
                filled: true,
                fillColor: AuthColors.background,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 16,
                ),
                border: border(AuthColors.border),
                enabledBorder: border(
                  invalid ? AuthColors.error : AuthColors.border,
                ),
                disabledBorder: border(AuthColors.border),
                focusedBorder: border(
                  invalid ? AuthColors.error : AuthColors.green,
                ),
                suffixIcon: password
                    ? IconButton(
                        tooltip: [
                          visible ? 'Hide' : 'Show',
                          label.toLowerCase(),
                        ].join(' '),
                        onPressed: enabled ? onToggleVisibility : null,
                        color: AuthColors.muted,
                        iconSize: 22,
                        icon: Icon(
                          visible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AuthError extends StatelessWidget {
  const AuthError(this.message, {super.key});
  final String? message;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 18),
    child: message == null
        ? const SizedBox.shrink()
        : Semantics(
            liveRegion: true,
            child: Text(
              message!,
              style: const TextStyle(
                color: AuthColors.error,
                fontSize: 11.5,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
  );
}

class AuthResetConfirmation extends StatelessWidget {
  const AuthResetConfirmation({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      constraints: const BoxConstraints(minHeight: 66),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AuthColors.soft,
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.check, size: 18, color: AuthColors.green),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Password reset email sent.',
                  style: TextStyle(
                    color: AuthColors.green,
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Check your inbox and spam folder.',
                  style: TextStyle(
                    color: AuthColors.green,
                    fontSize: 10.7,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class AuthButton extends StatelessWidget {
  const AuthButton({
    super.key,
    required this.label,
    required this.busyLabel,
    required this.onPressed,
    this.busy = false,
  });
  final String label;
  final String busyLabel;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => ElevatedButton(
    onPressed: busy ? null : onPressed,
    style: ElevatedButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      elevation: 0,
      backgroundColor: AuthColors.green,
      foregroundColor: Colors.white,
      disabledBackgroundColor: const Color(0xFF4E715D),
      disabledForegroundColor: Colors.white,
      textStyle: const TextStyle(
        fontSize: 13,
        height: 1.3,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy) ...[
          const SizedBox.square(
            dimension: 17,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
        ],
        Flexible(child: Text(busy ? busyLabel : label)),
      ],
    ),
  );
}

class AuthAccountLink extends StatelessWidget {
  const AuthAccountLink({
    super.key,
    required this.prompt,
    required this.label,
    required this.onPressed,
  });
  final String prompt;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        prompt,
        style: const TextStyle(
          color: AuthColors.muted,
          fontSize: 12,
          height: 1.4,
        ),
      ),
      TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: AuthColors.green,
          minimumSize: const Size(48, 44),
          textStyle: const TextStyle(
            fontSize: 15,
            height: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Text(label),
      ),
    ],
  );
}

class AuthStatusScreen extends StatelessWidget {
  const AuthStatusScreen({
    super.key,
    required this.title,
    required this.message,
    this.error = false,
  });
  final String title;
  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) => AuthPage(
    child: Padding(
      padding: const EdgeInsets.only(top: 54),
      child: Container(
        constraints: const BoxConstraints(minHeight: 356),
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 42),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          children: [
            if (error)
              const CircleAvatar(
                radius: 28,
                backgroundColor: Color(0xFFFAE7E0),
                child: Icon(Icons.close, color: AuthColors.error, size: 26),
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: SizedBox.square(
                  dimension: 28,
                  child: CircularProgressIndicator(
                    color: AuthColors.green,
                    strokeWidth: 2,
                  ),
                ),
              ),
            const SizedBox(height: 36),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AuthColors.ink,
                fontSize: 21,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: const TextStyle(
                color: AuthColors.muted,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
