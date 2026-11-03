import 'dart:convert';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

class AssistantImage {
  AssistantImage._(this.bytes, this.mimeType, this.name);
  static const maxBytes = 2 * 1024 * 1024;
  final Uint8List bytes;
  final String mimeType, name;

  factory AssistantImage.fromBytes(Uint8List bytes, {String name = 'Image'}) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException('Choose an image smaller than 2 MB.');
    }
    final String? mimeType;
    if (bytes.length >= 8 &&
        bytes.take(8).join(',') == '137,80,78,71,13,10,26,10') {
      mimeType = 'image/png';
    } else if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      mimeType = 'image/jpeg';
    } else if (bytes.length >= 12 &&
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
      mimeType = 'image/webp';
    } else {
      throw const FormatException('Choose a JPG, PNG or WebP image.');
    }
    return AssistantImage._(
      bytes,
      mimeType,
      name.trim().isEmpty ? 'Image' : name,
    );
  }

  static Future<AssistantImage> fromFile(XFile file) async {
    if (await file.length() > maxBytes) {
      throw const FormatException('Choose an image smaller than 2 MB.');
    }
    return AssistantImage.fromBytes(await file.readAsBytes(), name: file.name);
  }

  Map<String, String> toRequestData() => {
    'mimeType': mimeType,
    'data': base64Encode(bytes),
  };
}
