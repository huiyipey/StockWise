import 'package:flutter/material.dart';

// Build the shared report email preference component.
class ReportEmailPreference extends StatefulWidget {
  final Stream<bool> values;
  final Future<void> Function(bool) save;
  const ReportEmailPreference({
    super.key,
    required this.values,
    required this.save,
  });
  @override
  State<ReportEmailPreference> createState() => _ReportEmailPreferenceState();
}

// Manage the report email preference values and actions.
class _ReportEmailPreferenceState extends State<ReportEmailPreference> {
  // Keep this component's values, selections, and request state.
  bool saving = false;
  // Render the report email preference component.
  @override
  Widget build(BuildContext context) => StreamBuilder<bool>(
    stream: widget.values,
    builder: (context, snapshot) => SwitchListTile.adaptive(
      secondary: const Icon(Icons.mark_email_read_outlined),
      title: const Text('Email my reports'),
      subtitle: Text(
        snapshot.hasError
            ? 'Could not load preference. Reopen this page to retry.'
            : 'Weekly and monthly sales/waste reports for this shop, sent to your account email. Default: on.',
      ),
      value: snapshot.data ?? true,
      onChanged: saving || !snapshot.hasData || snapshot.hasError
          ? null
          : (value) async {
              setState(() => saving = true);
              try {
                await widget.save(value);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Could not save email preference. Please try again.',
                      ),
                    ),
                  );
                }
              } finally {
                if (mounted) setState(() => saving = false);
              }
            },
    ),
  );
}
