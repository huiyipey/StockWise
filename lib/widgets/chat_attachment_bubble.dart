import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/store_chat.dart';
import '../screens/product_image_screen.dart';
import '../services/chat_attachment_files.dart';
import '../services/store_chat_service.dart';

typedef ChatAttachmentOpener =
    Future<void> Function(Uint8List bytes, String name, String contentType);

class ChatAttachmentBubble extends StatefulWidget {
  final StoreChatMessage message;
  final String customerId;
  final StoreChatRepository repository;
  final ChatAttachmentOpener? openFile;
  const ChatAttachmentBubble({
    super.key,
    required this.message,
    required this.customerId,
    required this.repository,
    this.openFile,
  });
  @override
  State<ChatAttachmentBubble> createState() => _ChatAttachmentBubbleState();
}

class _ChatAttachmentBubbleState extends State<ChatAttachmentBubble> {
  Future<Uint8List>? download;
  bool opening = false;
  Future<Uint8List> _load() => download ??= widget.repository.loadAttachment(
    widget.customerId,
    widget.message,
  );

  Future<void> _open({bool save = false}) async {
    if (opening) return;
    setState(() => opening = true);
    final attachment = widget.message.attachment!;
    try {
      final bytes = await _load();
      if (!mounted) return;
      if (save) {
        final saved = await ChatAttachmentFiles.save(
          bytes,
          attachment.fileName,
          attachment.contentType,
        );
        if (saved && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Attachment downloaded')),
          );
        }
      } else {
        await (widget.openFile ?? ChatAttachmentFiles.open)(
          bytes,
          attachment.fileName,
          attachment.contentType,
        );
      }
    } catch (failure) {
      download = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failure is StateError
                  ? failure.message.toString()
                  : 'Could not open this attachment. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  Widget _fileButton() => TextButton.icon(
    onPressed: opening ? null : () => _open(),
    icon: const Icon(Icons.insert_drive_file_outlined),
    label: Text(
      widget.message.attachment!.fileName,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final attachment = widget.message.attachment!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (attachment.isImage)
          FutureBuilder<Uint8List>(
            future: _load(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return TextButton.icon(
                  onPressed: () => setState(() => download = null),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry photo'),
                );
              }
              if (!snapshot.hasData) {
                return const SizedBox(
                  width: 180,
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return Tooltip(
                message: 'Enlarge photo',
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (_) => ProductImageScreen(
                        image: MemoryImage(snapshot.data!),
                        title: attachment.fileName,
                      ),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      snapshot.data!,
                      width: 220,
                      height: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _fileButton(),
                    ),
                  ),
                ),
              );
            },
          )
        else
          _fileButton(),
        Row(
          children: [
            Expanded(
              child: Text(
                attachment.sizeLabel,
                style: const TextStyle(fontSize: 11),
              ),
            ),
            IconButton(
              tooltip: 'Download attachment',
              onPressed: opening ? null : () => _open(save: true),
              icon: opening
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
            ),
          ],
        ),
      ],
    );
  }
}
