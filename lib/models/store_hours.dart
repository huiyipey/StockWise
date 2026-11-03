class StoreHours {
  const StoreHours({this.opens = 540, this.closes = 1260});
  final int opens, closes;
  factory StoreHours.fromMap(dynamic value) => value is Map
      ? StoreHours(
          opens: (value['opens'] as num?)?.toInt() ?? 540,
          closes: (value['closes'] as num?)?.toInt() ?? 1260,
        )
      : const StoreHours();
  Map<String, dynamic> toMap() => {'opens': opens, 'closes': closes};
  bool get valid =>
      opens >= 0 && opens < 1440 && closes > opens + 30 && closes <= 1440;
  String clock(int value) =>
      '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
  String get label => '${clock(opens)} - ${clock(closes)}';
  String get lastOrderLabel => clock(closes - 30);
}
