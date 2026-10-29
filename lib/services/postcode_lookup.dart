import 'dart:convert';

import 'package:flutter/services.dart';

class PostcodeLocation {
  const PostcodeLocation({required this.city, required this.state});
  final String city;
  final String state;
}

typedef PostcodeLookup = Future<PostcodeLocation?> Function(String postcode);

/// A bundled, pinned Malaysian dataset keeps location lookup available offline.
class MalaysianPostcodes {
  static Map<String, dynamic>? _index;

  static Future<PostcodeLocation?> lookup(String postcode) async {
    if (_index == null) {
      final bytes = await rootBundle.load(
        'assets/data/malaysia_postcodes.json',
      );
      _index =
          jsonDecode(
                utf8.decode(
                  bytes.buffer.asUint8List(
                    bytes.offsetInBytes,
                    bytes.lengthInBytes,
                  ),
                ),
              )
              as Map<String, dynamic>;
    }
    final entry = _index![postcode];
    if (entry is! List || entry.length != 2) return null;
    return PostcodeLocation(
      city: entry[0] as String,
      state: entry[1] as String,
    );
  }
}
