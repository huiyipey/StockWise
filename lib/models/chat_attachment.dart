import 'dart:math';

import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

const chatAttachmentMaxBytes = 20 * 1024 * 1024;

String chatAttachmentPath(
  String storeId,
  String customerId,
  String senderId,
  String messageId,
) => 'stores/$storeId/chat-attachments/$customerId/$senderId/$messageId/file';

String safeAttachmentFileName(String name) {
  final clean = name.replaceAll(RegExp(r'[/\\\x00-\x1f:*?"<>|]'), '_').trim();
  return clean.isEmpty || clean == '.' || clean == '..' ? 'attachment' : clean;
}

String? chatAttachmentError(String name, int size) {
  if (name.trim().isEmpty || name.length > 180) {
    return 'Use a file name of 180 characters or fewer.';
  }
  if (size <= 0) return 'This file is empty. Please choose another file.';
  if (size > chatAttachmentMaxBytes) {
    return 'Please choose a file or photo no larger than 20 MB.';
  }
  return null;
}

class ChatAttachment {
  final String storagePath;
  final String fileName;
  final String contentType;
  final int size;
  const ChatAttachment({
    required this.storagePath,
    required this.fileName,
    required this.contentType,
    required this.size,
  });
  bool get isImage => contentType.startsWith('image/');
  String get sizeLabel => size >= 1024 * 1024
      ? '${(size / (1024 * 1024)).toStringAsFixed(1)} MB'
      : '${(size / 1024).ceil()} KB';
  Map<String, dynamic> toData() => {
    'storagePath': storagePath,
    'fileName': fileName,
    'contentType': contentType,
    'size': size,
  };
  factory ChatAttachment.fromData(Map<String, dynamic> data) => ChatAttachment(
    storagePath: data['storagePath'] as String,
    fileName: data['fileName'] as String,
    contentType: data['contentType'] as String,
    size: (data['size'] as num).toInt(),
  );
}

class ChatAttachmentDraft {
  final XFile file;
  final String messageId;
  final String fileName;
  final String contentType;
  final int size;
  const ChatAttachmentDraft({
    required this.file,
    required this.messageId,
    required this.fileName,
    required this.contentType,
    required this.size,
  });
  bool get isImage => contentType.startsWith('image/');
  static Future<ChatAttachmentDraft> fromFile(XFile file) async {
    final size = await file.length();
    final name = safeAttachmentFileName(file.name);
    final error = chatAttachmentError(name, size);
    if (error != null) throw ArgumentError(error);
    final header = await file
        .openRead(0, min(size, 32))
        .fold<List<int>>([], (all, chunk) => all..addAll(chunk));
    final type =
        lookupMimeType(name, headerBytes: header) ?? 'application/octet-stream';
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return ChatAttachmentDraft(
      file: file,
      messageId: id,
      fileName: name,
      contentType: type,
      size: size,
    );
  }

  ChatAttachment storedAt(String path) => ChatAttachment(
    storagePath: path,
    fileName: fileName,
    contentType: contentType,
    size: size,
  );
}

String chatMessagePreview(String text, ChatAttachment? attachment) =>
    text.trim().isNotEmpty
    ? text.trim()
    : '${attachment!.isImage ? 'Photo' : 'File'}: ${attachment.fileName}';
