import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _date(dynamic value) => value is Timestamp ? value.toDate() : null;

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

  bool hasUnread({required bool isAdmin}) {
    if (lastMessageAt == null ||
        lastSenderRole == (isAdmin ? 'admin' : 'customer')) {
      return false;
    }
    final readAt = isAdmin ? adminReadAt : customerReadAt;
    return readAt == null || lastMessageAt!.isAfter(readAt);
  }
}

class StoreChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String text;
  final DateTime? sentAt;

  const StoreChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.text,
    this.sentAt,
  });

  factory StoreChatMessage.fromData(String id, Map<String, dynamic> data) =>
      StoreChatMessage(
        id: id,
        senderId: data['senderId'] as String,
        senderName: data['senderName'] as String,
        senderRole: data['senderRole'] as String,
        text: data['text'] as String,
        sentAt: _date(data['sentAt']),
      );
}

String? chatMessageError(String text) {
  if (text.trim().isEmpty) return 'Please enter a message.';
  if (text.trim().length > 2000) return 'Use 2,000 characters or fewer.';
  return null;
}
