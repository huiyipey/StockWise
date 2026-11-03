import 'package:flutter/material.dart';

import '../services/password_change_service.dart';
import '../services/password_policy.dart';
import '../widgets/inventory_ui.dart';
import '../widgets/profile_ui.dart';

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
    style: const TextStyle(fontSize: 13),
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
  Widget build(BuildContext context) => ProfileFormPage(
    title: 'Change Password',
    busy: saving,
    dirty: [
      currentPassword,
      newPassword,
      confirmation,
    ].any((field) => field.text.isNotEmpty),
    body: Form(
      onChanged: () => setState(() {}),
      key: form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          ProfilePanel(
            padding: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Enter your current password, then choose and confirm a new password.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: InventoryColors.muted,
                  ),
                ),
                const SizedBox(height: 24),
                _passwordField(
                  index: 0,
                  label: 'Current password',
                  controller: currentPassword,
                  validator: currentPasswordError,
                  autofillHint: AutofillHints.password,
                ),
                const SizedBox(height: 22),
                _passwordField(
                  index: 1,
                  label: 'New password',
                  controller: newPassword,
                  validator: (value) =>
                      newPasswordError(value, currentPassword.text),
                  autofillHint: AutofillHints.newPassword,
                ),
                const SizedBox(height: 10),
                const Text(
                  passwordRequirements,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: InventoryColors.muted,
                  ),
                ),
                const SizedBox(height: 22),
                _passwordField(
                  index: 2,
                  label: 'Confirm new password',
                  controller: confirmation,
                  validator: (value) =>
                      confirmPasswordError(value, newPassword.text),
                  autofillHint: AutofillHints.newPassword,
                ),
                if (error != null) ...[
                  const SizedBox(height: 18),
                  ProfileNotice(error!, error: true),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
    footer: ProfileFooter(
      label: saving ? 'Changing...' : 'Change Password',
      busy: saving,
      onPressed: saving ? null : _save,
    ),
  );
}
