import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_attachment.dart';

// Read a stored chat timestamp with a safe fallback.
DateTime? _date(dynamic value) => value is Timestamp ? value.toDate() : null;

// Keep the store conversation values used by the app.
class StoreConversation {
  final String customerId;
  final String customerName;
  final String lastMessage;
  final String lastSenderRole;
  final DateTime? lastMessageAt;
  final DateTime? customerReadAt;
  final DateTime? adminReadAt;

  const StoreConversation({
    required this.customerId,
    required this.customerName,
    required this.lastMessage,
    required this.lastSenderRole,
    this.lastMessageAt,
    this.customerReadAt,
    this.adminReadAt,
  });

  // Read the saved record fields with safe defaults.
  factory StoreConversation.fromData(String id, Map<String, dynamic> data) =>
      StoreConversation(
        customerId: id,
        customerName: data['customerName'] as String? ?? 'Customer',
        lastMessage: data['lastMessage'] as String? ?? '',
        lastSenderRole: data['lastSenderRole'] as String? ?? 'customer',
        lastMessageAt: _date(data['lastMessageAt']),
        customerReadAt: _date(data['customerReadAt']),
        adminReadAt: _date(data['adminReadAt']),
      );

  // Check whether this viewer has unread messages.
  bool hasUnread({required bool isAdmin}) {
    if (lastMessageAt == null ||
        lastSenderRole == (isAdmin ? 'admin' : 'customer')) {
      return false;
    }
    final readAt = isAdmin ? adminReadAt : customerReadAt;
    return readAt == null || lastMessageAt!.isAfter(readAt);
  }

  // Return the unread count for this viewer.
  int unreadMessageCount(
    Iterable<StoreChatMessage> messages, {
    required bool isAdmin,
  }) {
    // Sending a reply marks the preceding messages read. This also handles
    // legacy conversation records that do not yet carry a read timestamp.
    if (lastSenderRole == (isAdmin ? 'admin' : 'customer')) return 0;
    final readAt = isAdmin ? adminReadAt : customerReadAt;
    final incomingRole = isAdmin ? 'customer' : 'admin';
    return messages
        .where(
          (message) =>
              message.senderRole == incomingRole &&
              message.sentAt != null &&
              (readAt == null || message.sentAt!.isAfter(readAt)),
        )
        .length;
  }
}

// Keep the store chat message values used by the app.
class StoreChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String text;
  final DateTime? sentAt;
  final ChatAttachment? attachment;

  const StoreChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.text,
    this.sentAt,
    this.attachment,
  });

  // Read the saved record fields with safe defaults.
  factory StoreChatMessage.fromData(String id, Map<String, dynamic> data) =>
      StoreChatMessage(
        id: id,
        senderId: data['senderId'] as String,
        senderName: data['senderName'] as String,
        senderRole: data['senderRole'] as String,
        text: data['text'] as String,
        sentAt: _date(data['sentAt']),
        attachment: data['attachment'] is Map
            ? ChatAttachment.fromData(
                Map<String, dynamic>.from(data['attachment'] as Map),
              )
            : null,
      );
}

// Convert chat failures to short user-facing messages.
String? chatMessageError(String text, {bool hasAttachment = false}) {
  if (text.trim().isEmpty && !hasAttachment) return 'Please enter a message.';
  if (text.trim().length > 2000) return 'Use 2,000 characters or fewer.';
  return null;
}
