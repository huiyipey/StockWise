import 'dart:math';

import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

const chatAttachmentMaxBytes = 20 * 1024 * 1024;

// Build an attachment path inside this shop conversation.
String chatAttachmentPath(
  String storeId,
  String customerId,
  String senderId,
  String messageId,
) => 'stores/$storeId/chat-attachments/$customerId/$senderId/$messageId/file';

// Remove unsafe characters from the attachment file name.
String safeAttachmentFileName(String name) {
  final clean = name.replaceAll(RegExp(r'[/\\\x00-\x1f:*?"<>|]'), '_').trim();
  return clean.isEmpty || clean == '.' || clean == '..' ? 'attachment' : clean;
}

// Reject unsupported types and oversized attachment files.
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

// Keep the chat attachment values used by the app.
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
  // Check whether the attachment is an image.
  bool get isImage => contentType.startsWith('image/');
  // Format the attachment size for display.
  String get sizeLabel => size >= 1024 * 1024
      ? '${(size / (1024 * 1024)).toStringAsFixed(1)} MB'
      : '${(size / 1024).ceil()} KB';
  // Convert this record to fields that can be saved.
  Map<String, dynamic> toData() => {
    'storagePath': storagePath,
    'fileName': fileName,
    'contentType': contentType,
    'size': size,
  };
  // Read the saved record fields with safe defaults.
  factory ChatAttachment.fromData(Map<String, dynamic> data) => ChatAttachment(
    storagePath: data['storagePath'] as String,
    fileName: data['fileName'] as String,
    contentType: data['contentType'] as String,
    size: (data['size'] as num).toInt(),
  );
}

// Keep the chat attachment draft values used by the app.
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
  // Check whether the attachment is an image.
  bool get isImage => contentType.startsWith('image/');
  // Read and validate the chosen image or attachment.
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

  // Attach the uploaded storage path to this file metadata.
  ChatAttachment storedAt(String path) => ChatAttachment(
    storagePath: path,
    fileName: fileName,
    contentType: contentType,
    size: size,
  );
}

// Summarize text or attachment details for the conversation list.
String chatMessagePreview(String text, ChatAttachment? attachment) =>
    text.trim().isNotEmpty
    ? text.trim()
    : '${attachment!.isImage ? 'Photo' : 'File'}: ${attachment.fileName}';
