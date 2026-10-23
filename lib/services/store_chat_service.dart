import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/store_chat.dart';
import 'store_session.dart';

abstract class StoreChatRepository {
  String get currentUserId;
  String get storeName;
  bool get isAdmin;
  Stream<List<StoreConversation>> watchConversations();
  Stream<StoreConversation?> watchConversation(String customerId);
  Stream<List<StoreChatMessage>> watchMessages(String customerId);
  Future<void> sendMessage(String customerId, String text);
  Future<void> markRead(String customerId, DateTime through);
}

class StoreChatService implements StoreChatRepository {
  final String storeId;
  @override
  final String currentUserId;
  @override
  final String storeName;
  @override
  final bool isAdmin;
  final FirebaseFirestore _db;

  StoreChatService._(
    this._db, {
    required this.storeId,
    required this.currentUserId,
    required this.storeName,
    required this.isAdmin,
  });

  factory StoreChatService.forSelectedStore() {
    final session = StoreSession.instance;
    final store = session.store;
    final user = FirebaseAuth.instance.currentUser;
    if (store == null || user == null) {
      throw StateError('Please sign in and select a store.');
    }
    return StoreChatService._(
      FirebaseFirestore.instance,
      storeId: store.id,
      currentUserId: user.uid,
      storeName: store.name,
      isAdmin: session.canManageMembers,
    );
  }

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _db.collection('stores').doc(storeId).collection('conversations');

  @override
  Stream<List<StoreConversation>> watchConversations() {
    if (!isAdmin) {
      return watchConversation(currentUserId).map((row) => [?row]);
    }
    return _conversations
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => StoreConversation.fromData(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Stream<StoreConversation?> watchConversation(String customerId) =>
      _conversations
          .doc(customerId)
          .snapshots()
          .map(
            (doc) => doc.exists
                ? StoreConversation.fromData(doc.id, doc.data()!)
                : null,
          );

  @override
  Stream<List<StoreChatMessage>> watchMessages(String customerId) =>
      _conversations
          .doc(customerId)
          .collection('messages')
          .orderBy('sentAt', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => StoreChatMessage.fromData(doc.id, doc.data()))
                .toList(),
          );

  @override
  Future<void> sendMessage(String customerId, String text) async {
    final error = chatMessageError(text);
    if (error != null) throw ArgumentError(error);
    if (!isAdmin && customerId != currentUserId) {
      throw StateError('You can only send messages in your own conversation.');
    }
    final conversation = _conversations.doc(customerId);
    final message = conversation.collection('messages').doc();
    await _db.runTransaction((transaction) async {
      final existing = await transaction.get(conversation);
      final profile = await transaction.get(
        _db.collection('users').doc(currentUserId),
      );
      final name = profile.data()?['displayName'] as String? ?? '';
      if (name.trim().isEmpty || name.length > 80) {
        throw StateError('Please add a valid name in Edit profile first.');
      }
      if (isAdmin && !existing.exists) {
        throw StateError('This customer has not started a conversation yet.');
      }
      final timestamp = FieldValue.serverTimestamp();
      final role = isAdmin ? 'admin' : 'customer';
      transaction.set(message, {
        'senderId': currentUserId,
        'senderName': name,
        'senderRole': role,
        'text': text.trim(),
        'sentAt': timestamp,
      });
      transaction.set(conversation, {
        if (!existing.exists) ...{
          'storeId': storeId,
          'customerId': customerId,
          'adminReadAt': null,
        },
        if (!isAdmin) 'customerName': name,
        'lastMessageId': message.id,
        'lastMessage': text.trim(),
        'lastMessageAt': timestamp,
        'lastSenderId': currentUserId,
        'lastSenderRole': role,
        isAdmin ? 'adminReadAt' : 'customerReadAt': timestamp,
      }, SetOptions(merge: true));
    });
  }

  @override
  Future<void> markRead(String customerId, DateTime through) =>
      _db.runTransaction((transaction) async {
        final ref = _conversations.doc(customerId);
        final doc = await transaction.get(ref);
        if (!doc.exists) return;
        final row = StoreConversation.fromData(doc.id, doc.data()!);
        final alreadyRead = isAdmin ? row.adminReadAt : row.customerReadAt;
        if (row.lastMessageAt != null &&
            !through.isAfter(row.lastMessageAt!) &&
            (alreadyRead == null || through.isAfter(alreadyRead))) {
          transaction.update(ref, {
            isAdmin ? 'adminReadAt' : 'customerReadAt': Timestamp.fromDate(
              through,
            ),
          });
        }
      });
}
