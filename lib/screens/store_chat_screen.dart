import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/store_chat.dart';
import '../services/store_chat_service.dart';
import '../theme/app_theme.dart';
import '../models/chat_attachment.dart';
import '../services/chat_attachment_files.dart';
import '../widgets/chat_attachment_bubble.dart';

class StoreChatScreen extends StatefulWidget {
  final StoreChatRepository repository;
  final String customerId;
  final String? customerName;
  final Future<ChatAttachmentDraft?> Function(ChatAttachmentSource)?
  pickAttachment;
  final ChatAttachmentOpener? openAttachment;

  const StoreChatScreen({
    super.key,
    required this.repository,
    required this.customerId,
    this.customerName,
    this.pickAttachment,
    this.openAttachment,
  });

  @override
  State<StoreChatScreen> createState() => _StoreChatScreenState();
}

class _StoreChatScreenState extends State<StoreChatScreen> {
  final draft = TextEditingController();
  final scroll = ScrollController();
  late final messages = widget.repository.watchMessages(widget.customerId);
  StreamSubscription<StoreConversation?>? subscription;
  StoreConversation? latest;
  DateTime? acknowledged;
  bool reading = false;
  bool sending = false;
  bool messagesLoaded = false;
  DateTime? loadedThrough;
  String? error;
  ChatAttachmentDraft? attachment;
  Future<Uint8List>? attachmentPreview;
  bool picking = false;

  @override
  void initState() {
    super.initState();
    subscription = widget.repository
        .watchConversation(widget.customerId)
        .listen(
          (row) {
            latest = row;
            _scheduleRead();
          },
          onError:
              (Object _) {}, // The message stream displays access/load errors.
        );
  }

  void _scheduleRead() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
  }

  Future<void> _markRead() async {
    final row = latest;
    if (!mounted ||
        !messagesLoaded ||
        reading ||
        row == null ||
        loadedThrough == null ||
        row.lastMessageAt == null ||
        loadedThrough!.isBefore(row.lastMessageAt!) ||
        ModalRoute.of(context)?.isCurrent != true ||
        !row.hasUnread(isAdmin: widget.repository.isAdmin) ||
        row.lastMessageAt == acknowledged) {
      return;
    }
    reading = true;
    try {
      await widget.repository.markRead(widget.customerId, row.lastMessageAt!);
      acknowledged = row.lastMessageAt;
      if (latest?.lastMessageAt != row.lastMessageAt) _scheduleRead();
    } catch (_) {
      // Keep unread status if the network/access check fails; retry on next data.
    } finally {
      reading = false;
    }
  }

  @override
  void dispose() {
    subscription?.cancel();
    draft.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (sending || picking) return;
    final original = draft.text;
    final selected = attachment;
    final validation = chatMessageError(
      original,
      hasAttachment: selected != null,
    );
    if (validation != null) {
      setState(() => error = validation);
      return;
    }
    setState(() {
      sending = true;
      error = null;
    });
    try {
      await widget.repository.sendMessage(
        widget.customerId,
        original,
        attachment: selected,
      );
      if (!mounted) return;
      if (draft.text == original) draft.clear();
      if (identical(attachment, selected)) {
        setState(() {
          attachment = null;
          attachmentPreview = null;
        });
      }
      if (scroll.hasClients) {
        scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    } catch (failure) {
      if (!mounted) return;
      setState(
        () => error = failure is ArgumentError
            ? '${failure.message}'
            : failure is StateError
            ? failure.message.toString()
            : 'Message could not be sent. Please try again.',
      );
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _pickAttachment() async {
    if (sending || picking) return;
    FocusScope.of(context).unfocus();
    final source = await showModalBottomSheet<ChatAttachmentSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Photo'),
              onTap: () => Navigator.pop(context, ChatAttachmentSource.photo),
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('File'),
              onTap: () => Navigator.pop(context, ChatAttachmentSource.file),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() {
      picking = true;
      error = null;
    });
    try {
      final selected =
          await (widget.pickAttachment ?? ChatAttachmentFiles.pick)(source);
      if (selected == null || !mounted) return;
      final validation = chatAttachmentError(selected.fileName, selected.size);
      if (validation != null) throw ArgumentError(validation);
      setState(() {
        attachment = selected;
        attachmentPreview = selected.isImage
            ? selected.file.readAsBytes()
            : null;
      });
    } catch (failure) {
      if (mounted) {
        setState(
          () => error = failure is ArgumentError
              ? '${failure.message}'
              : 'Could not attach this file. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.repository.isAdmin
                ? widget.customerName ?? 'Customer'
                : 'Chat with admin',
          ),
          Text(
            widget.repository.storeName,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    ),
    body: Column(
      children: [
        Expanded(
          child: StreamBuilder<List<StoreChatMessage>>(
            stream: messages,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Could not load messages. Check your connection and reopen this chat.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              messagesLoaded = true;
              _scheduleRead();
              final rows = snapshot.data!;
              loadedThrough = rows
                  .where((row) => row.sentAt != null)
                  .map((row) => row.sentAt!)
                  .fold<DateTime?>(
                    null,
                    (latest, time) =>
                        latest == null || time.isAfter(latest) ? time : latest,
                  );
              if (rows.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Text(
                      'Send a message to start a conversation with the store admin.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView.builder(
                controller: scroll,
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final message = rows[index];
                  final mine =
                      message.senderId == widget.repository.currentUserId;
                  return Align(
                    alignment: mine
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * .8,
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: mine
                            ? AppColors.primary.withValues(alpha: .12)
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mine
                                ? 'You'
                                : '${message.senderName}${message.senderRole == 'admin' ? ' • Admin' : ''}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 5),
                          if (message.attachment != null)
                            ChatAttachmentBubble(
                              key: ValueKey('attachment-${message.id}'),
                              message: message,
                              customerId: widget.customerId,
                              repository: widget.repository,
                              openFile: widget.openAttachment,
                            ),
                          if (message.text.isNotEmpty)
                            SelectableText(message.text),
                          const SizedBox(height: 5),
                          Text(
                            message.sentAt == null
                                ? 'Sending…'
                                : DateFormat(
                                    'd MMM, h:mm a',
                                  ).format(message.sentAt!),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (attachment != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                if (attachmentPreview != null)
                  FutureBuilder<Uint8List>(
                    future: attachmentPreview,
                    builder: (context, snapshot) => snapshot.hasData
                        ? Image.memory(
                            snapshot.data!,
                            width: 54,
                            height: 54,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.image_outlined),
                          )
                        : const SizedBox(
                            width: 54,
                            height: 54,
                            child: Center(child: Icon(Icons.image_outlined)),
                          ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    attachment!.fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Remove attachment',
                  onPressed: sending
                      ? null
                      : () => setState(() {
                          attachment = null;
                          attachmentPreview = null;
                        }),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Attach file or photo',
                  onPressed: sending || picking ? null : _pickAttachment,
                  icon: picking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.attach_file_rounded),
                ),
                Expanded(
                  child: TextField(
                    controller: draft,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Type a message or caption',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  tooltip: 'Send message',
                  onPressed: sending || picking ? null : _send,
                  icon: sending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
