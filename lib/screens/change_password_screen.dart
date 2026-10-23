import 'package:flutter/material.dart';

import '../services/password_change_service.dart';
import '../theme/app_theme.dart';
import '../widgets/stockwise_ui.dart';

class ChangePasswordScreen extends StatefulWidget {
  final PasswordChanger? onChangePassword;
  const ChangePasswordScreen({super.key, this.onChangePassword});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final form = GlobalKey<FormState>();
  final currentPassword = TextEditingController();
  final newPassword = TextEditingController();
  final confirmation = TextEditingController();
  final visible = [false, false, false];
  bool saving = false;
  String? error;

  @override
  void dispose() {
    currentPassword.dispose();
    newPassword.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (saving || !(form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await (widget.onChangePassword ?? PasswordChangeService.instance.change)(
        currentPassword: currentPassword.text,
        newPassword: newPassword.text,
      );
      if (!mounted) return;
      currentPassword.clear();
      newPassword.clear();
      confirmation.clear();
      setState(() => saving = false);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context, true);
    } catch (failure) {
      if (mounted) {
        setState(
          () => error = failure is PasswordChangeFailure
              ? failure.message
              : 'Could not change your password. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _passwordField({
    required int index,
    required String label,
    required TextEditingController controller,
    required FormFieldValidator<String> validator,
    required String autofillHint,
  }) => TextFormField(
    key: ValueKey('password-$index'),
    controller: controller,
    enabled: !saving,
    obscureText: !visible[index],
    autocorrect: false,
    enableSuggestions: false,
    autofillHints: [autofillHint],
    keyboardType: TextInputType.visiblePassword,
    textInputAction: index == 2 ? TextInputAction.done : TextInputAction.next,
    onFieldSubmitted: index == 2 ? (_) => _save() : null,
    decoration: InputDecoration(
      labelText: label,
      suffixIcon: IconButton(
        tooltip: '${visible[index] ? 'Hide' : 'Show'} ${label.toLowerCase()}',
        onPressed: saving
            ? null
            : () => setState(() => visible[index] = !visible[index]),
        icon: Icon(
          visible[index]
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
        ),
      ),
    ),
    validator: validator,
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            StockWiseHeader(
              title: 'Change Password',
              leading: saving ? null : const BackCircleButton(),
            ),
            Expanded(
              child: Form(
                key: form,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      'Enter your current password, then choose and confirm a new password.',
                    ),
                    const SizedBox(height: 24),
                    _passwordField(
                      index: 0,
                      label: 'Current password',
                      controller: currentPassword,
                      validator: currentPasswordError,
                      autofillHint: AutofillHints.password,
                    ),
                    const SizedBox(height: 16),
                    _passwordField(
                      index: 1,
                      label: 'New password',
                      controller: newPassword,
                      validator: (value) =>
                          newPasswordError(value, currentPassword.text),
                      autofillHint: AutofillHints.newPassword,
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Use at least 6 characters.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _passwordField(
                      index: 2,
                      label: 'Confirm new password',
                      controller: confirmation,
                      validator: (value) =>
                          confirmPasswordError(value, newPassword.text),
                      autofillHint: AutofillHints.newPassword,
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          error!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: saving ? null : _save,
                      child: Text(saving ? 'CHANGING...' : 'CHANGE PASSWORD'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
