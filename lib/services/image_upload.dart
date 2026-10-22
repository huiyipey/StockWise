import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

class ImageUpload {
  final Uint8List bytes;
  final String contentType;
  final String extension;
  ImageUpload(this.bytes, this.contentType, this.extension);
  static Future<ImageUpload> read(XFile file) async =>
      fromBytes(await file.readAsBytes());
  static ImageUpload fromBytes(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length >= 5 * 1024 * 1024) {
      throw ArgumentError('Choose an image smaller than 5 MB.');
    }
    if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      return ImageUpload(bytes, 'image/jpeg', 'jpg');
    }
    if (bytes.length >= 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71) {
      return ImageUpload(bytes, 'image/png', 'png');
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return ImageUpload(bytes, 'image/webp', 'webp');
    }
    throw ArgumentError('Choose a JPG, PNG or WebP image.');
  }
}
