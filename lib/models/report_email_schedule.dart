// Keep the report cadence values used by the app.
enum ReportCadence {
  daily('Daily'),
  weekly('Weekly'),
  monthly('Monthly'),
  yearly('Yearly');

  const ReportCadence(this.label);
  final String label;
}

// Keep the report email schedule values used by the app.
class ReportEmailSchedule {
  const ReportEmailSchedule({
    this.sales = const {ReportCadence.weekly},
    this.waste = const {ReportCadence.weekly},
  });
  final Set<ReportCadence> sales, waste;
  // Check whether at least one report email schedule is selected.
  bool get enabled => sales.isNotEmpty || waste.isNotEmpty;
  // Read the email schedules saved on this shop membership.
  factory ReportEmailSchedule.fromMember(Map<String, dynamic> data) {
    if (data['reportsByEmail'] == false) {
      return const ReportEmailSchedule(sales: {}, waste: {});
    }
    final schedules = data['reportEmailSchedules'];
    // Read valid, unique cadences for one report type.
    Set<ReportCadence> parse(String kind) {
      final raw = schedules is Map ? schedules[kind] : null;
      if (raw is! List) return {ReportCadence.weekly};
      return ReportCadence.values.where((c) => raw.contains(c.name)).toSet();
    }

    return ReportEmailSchedule(sales: parse('sales'), waste: parse('waste'));
  }
  // Convert the selected values to Firestore fields.
  Map<String, List<String>> toMap() => {
    'sales': [
      for (final c in ReportCadence.values)
        if (sales.contains(c)) c.name,
    ],
    'waste': [
      for (final c in ReportCadence.values)
        if (waste.contains(c)) c.name,
    ],
  };
  // Summarize the active report email schedules.
  String get subtitle {
    if (!enabled) return 'Email reports are disabled';
    if (sales.length == 1 &&
        waste.length == 1 &&
        sales.contains(ReportCadence.weekly) &&
        waste.contains(ReportCadence.weekly)) {
      return 'Sales and waste reports are sent weekly';
    }
    // Build the label shown to the user.
    String label(Set<ReportCadence> values) => values.isEmpty
        ? 'Off'
        : ReportCadence.values
              .where(values.contains)
              .map((e) => e.label)
              .join(', ');
    return 'Sales: ${label(sales)}\nWaste: ${label(waste)}';
  }
}
