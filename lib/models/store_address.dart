class StoreAddress {
  const StoreAddress({
    required this.line1,
    this.line2 = '',
    required this.postcode,
    required this.city,
    required this.state,
  });

  final String line1;
  final String line2;
  final String postcode;
  final String city;
  final String state;

  String get formatted => [
    line1.trim(),
    if (line2.trim().isNotEmpty) line2.trim(),
    '${postcode.trim()} ${city.trim()}, ${state.trim()}',
  ].join('\n');

  Map<String, String> toMap() => {
    'line1': line1.trim(),
    'line2': line2.trim(),
    'postcode': postcode.trim(),
    'city': city.trim(),
    'state': state.trim(),
  };

  static StoreAddress? fromMap(Object? value) {
    if (value is! Map) return null;
    if (['line1', 'postcode', 'city', 'state'].any(
      (key) => value[key] is! String || (value[key] as String).trim().isEmpty,
    )) {
      return null;
    }
    return StoreAddress(
      line1: value['line1'] as String,
      line2: value['line2'] as String? ?? '',
      postcode: value['postcode'] as String,
      city: value['city'] as String,
      state: value['state'] as String,
    );
  }
}
