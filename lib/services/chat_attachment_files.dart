import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';

import '../models/chat_attachment.dart';

enum ChatAttachmentSource { photo, file }

class ChatAttachmentFiles {
  static Future<ChatAttachmentDraft?> pick(ChatAttachmentSource source) async {
    final XFile? file;
    if (source == ChatAttachmentSource.photo) {
      file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 2400,
        maxHeight: 2400,
      );
    } else {
      final path = await FlutterFileDialog.pickFile(
        params: const OpenFileDialogParams(copyFileToCacheDir: true),
      );
      file = path == null ? null : XFile(path);
    }
    return file == null ? null : ChatAttachmentDraft.fromFile(file);
  }

  static Future<void> open(
    Uint8List data,
    String name,
    String contentType,
  ) async {
    final folder = await Directory.systemTemp.createTemp('stockwise-chat-');
    final file = File('${folder.path}/${safeAttachmentFileName(name)}');
    await file.writeAsBytes(data, flush: true);
    final result = await OpenFilex.open(file.path, type: contentType);
    if (result.type != ResultType.done) {
      throw StateError(
        'No app could open this file. Use Download to save it instead.',
      );
    }
  }

  static Future<bool> save(
    Uint8List data,
    String name,
    String contentType,
  ) async =>
      await FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(
          data: data,
          fileName: safeAttachmentFileName(name),
          mimeTypesFilter: [contentType],
        ),
      ) !=
      null;
}
