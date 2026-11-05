import 'package:flutter/material.dart';
import '../models/report_email_schedule.dart';
import '../widgets/inventory_ui.dart';
import '../widgets/profile_ui.dart';

class ReportEmailSettingsScreen extends StatefulWidget {
  const ReportEmailSettingsScreen({
    super.key,
    required this.initial,
    required this.save,
  });
  final ReportEmailSchedule initial;
  final Future<void> Function(ReportEmailSchedule) save;
  @override
  State<ReportEmailSettingsScreen> createState() =>
      _ReportEmailSettingsScreenState();
}

class _ReportEmailSettingsScreenState extends State<ReportEmailSettingsScreen> {
  late final sales = {...widget.initial.sales},
      waste = {...widget.initial.waste};
  bool saving = false;
  String? error;
  Future<void> submit() async {
    setState(() {
      saving = true;
      error = null;
    });
    final value = ReportEmailSchedule(sales: sales, waste: waste);
    try {
      await widget.save(value);
      if (mounted) Navigator.pop(context, value);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not save report schedules. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => InventoryTheme(
    child: Scaffold(
      backgroundColor: InventoryColors.background,
      appBar: AppBar(title: const Text('Email Report Schedule')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Choose when to receive each report. You can select more than one schedule, or clear every option to turn a report off.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: InventoryColors.muted,
              ),
            ),
            for (final kind in ['sales', 'waste']) ...[
              ProfileSection(
                kind == 'sales' ? 'Sales Reports' : 'Waste Reports',
              ),
              ProfilePanel(
                padding: 0,
                child: Column(
                  children: [
                    for (final cadence in ReportCadence.values)
                      CheckboxListTile(
                        key: ValueKey('report-email-$kind-${cadence.name}'),
                        title: Text(
                          cadence.label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          switch (cadence) {
                            ReportCadence.daily =>
                              'Every morning · previous day',
                            ReportCadence.weekly =>
                              'Monday · previous Monday–Sunday',
                            ReportCadence.monthly =>
                              'First day of the month · previous month',
                            ReportCadence.yearly => '1 January · previous year',
                          },
                          style: const TextStyle(
                            fontSize: 11,
                            color: InventoryColors.muted,
                          ),
                        ),
                        activeColor: InventoryColors.green,
                        value: (kind == 'sales' ? sales : waste).contains(
                          cadence,
                        ),
                        onChanged: saving
                            ? null
                            : (checked) => setState(() {
                                final selected = kind == 'sales'
                                    ? sales
                                    : waste;
                                checked == true
                                    ? selected.add(cadence)
                                    : selected.remove(cadence);
                              }),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Sent at 9:00 AM Malaysia time to your account email. Weekly is the default for both report types.',
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: InventoryColors.muted,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              ProfileNotice(error!, error: true),
            ],
            const SizedBox(height: 20),
            InventoryButton(
              key: const ValueKey('save-report-email-schedule'),
              label: 'Save Schedule',
              onPressed: saving ? null : submit,
              busy: saving,
            ),
          ],
        ),
      ),
    ),
  );
}
