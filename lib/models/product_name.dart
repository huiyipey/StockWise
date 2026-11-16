final _wordStart = RegExp(r'(^|[\s-])(\S)', unicode: true);
final _packMultiplier = RegExp(r'(\d)(\s+)X(\s*)(?=\d)', unicode: true);

const productNameHint = 'e.g. Fresh Milk 5 x 100ml';

/// Uppercase word initials while retaining the rest of each product's spelling.
String capitalizeProductName(String value) {
  final titled = value.replaceAllMapped(
    _wordStart,
    (match) => '${match[1]}${match[2]!.toUpperCase()}',
  );
  // Keep the multiplication marker in pack sizes lowercase.
  return titled.replaceAllMapped(
    _packMultiplier,
    (match) => '${match[1]}${match[2]}x${match[3]}',
  );
}
