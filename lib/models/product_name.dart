final _wordStart = RegExp(r'(^|[\s-])(\S)', unicode: true);

/// Uppercase word initials while retaining the rest of each product's spelling.
String capitalizeProductName(String value) => value.replaceAllMapped(
  _wordStart,
  (match) => '${match[1]}${match[2]!.toUpperCase()}',
);
