import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_ui.dart';

class StorePrimaryButton extends StatelessWidget {
  const StorePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      backgroundColor: AuthColors.green,
      foregroundColor: Colors.white,
      disabledBackgroundColor: const Color(0xFFDEE7DF),
      disabledForegroundColor: AuthColors.muted,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy) ...[
          const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
        ],
        Flexible(child: Text(label)),
      ],
    ),
  );
}

class StoreAddressField extends StatelessWidget {
  const StoreAddressField({
    super.key,
    required this.fieldKey,
    required this.label,
    required this.controller,
    required this.hint,
    this.optional = false,
    this.readOnly = false,
    this.enabled = true,
    this.maxLines = 1,
    this.validator,
    this.onChanged,
    this.keyboardType,
    this.inputFormatters,
    this.suffix,
    this.error,
  });
  final String fieldKey;
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool optional, readOnly, enabled;
  final int maxLines;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffix;
  final String? error;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(color: color),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$label${optional ? '' : ' *'}',
                  style: const TextStyle(
                    color: AuthColors.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (optional)
                const Text(
                  'Optional',
                  style: TextStyle(color: AuthColors.muted, fontSize: 10),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey(fieldKey),
            controller: controller,
            enabled: enabled,
            readOnly: readOnly,
            minLines: 1,
            maxLines: maxLines,
            keyboardType: keyboardType,
            textCapitalization: keyboardType == TextInputType.number
                ? TextCapitalization.none
                : TextCapitalization.words,
            inputFormatters: inputFormatters,
            textInputAction: TextInputAction.next,
            onChanged: onChanged,
            validator: validator,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            scrollPadding: const EdgeInsets.all(28),
            style: const TextStyle(color: AuthColors.ink, fontSize: 13.5),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AuthColors.muted, fontSize: 13),
              filled: true,
              fillColor: readOnly || !enabled
                  ? const Color(0xFFEEF1ED)
                  : AuthColors.background,
              contentPadding: const EdgeInsets.all(15),
              border: border(AuthColors.border),
              enabledBorder: border(AuthColors.border),
              disabledBorder: border(AuthColors.border),
              focusedBorder: border(AuthColors.green),
              errorBorder: border(AuthColors.error),
              focusedErrorBorder: border(AuthColors.error),
              errorStyle: const TextStyle(
                color: AuthColors.error,
                fontSize: 11,
              ),
              errorMaxLines: 3,
              errorText: error,
              suffixIcon: suffix,
            ),
          ),
        ],
      ),
    );
  }
}
