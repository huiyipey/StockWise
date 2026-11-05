class StoreHours {
  const StoreHours({
    this.opens = 540,
    this.closes = 1260,
    this.closedDays = const {},
  });
  final int opens, closes;

  /// ISO weekdays: Monday = 1 through Sunday = 7.
  final Set<int> closedDays;
  factory StoreHours.fromMap(dynamic value) => value is Map
      ? StoreHours(
          opens: (value['opens'] as num?)?.toInt() ?? 540,
          closes: (value['closes'] as num?)?.toInt() ?? 1260,
          closedDays: {
            for (final day
                in value['closedDays'] is Iterable
                    ? value['closedDays'] as Iterable
                    : const [])
              if (day is int && day >= 1 && day <= 7) day,
          },
        )
      : const StoreHours();
  Map<String, dynamic> toMap() => {
    'opens': opens,
    'closes': closes,
    'closedDays': closedDays.toList()..sort(),
  };
  bool get valid =>
      opens >= 0 &&
      opens < 1440 &&
      closes > opens + 30 &&
      closes <= 1440 &&
      closedDays.every((day) => day >= 1 && day <= 7);
  bool isClosedOn(DateTime localDate) => closedDays.contains(localDate.weekday);
  static const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  String get closedDaysLabel => closedDays.isEmpty
      ? 'No closed days'
      : closedDays.length == 7
      ? 'Closed every day'
      : 'Closed ${[for (var day = 1; day <= 7; day++)
          if (closedDays.contains(day)) dayNames[day - 1]].join(', ')}';
  String clock(int value) =>
      '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
  String get label => '${clock(opens)} - ${clock(closes)} · $closedDaysLabel';
  String get lastOrderLabel => clock(closes - 30);
}
