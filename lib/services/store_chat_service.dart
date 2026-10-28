import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import '../models/chat_attachment.dart';

import '../models/store_chat.dart';
import 'store_session.dart';

abstract class StoreChatRepository {
  String get currentUserId;
  String get storeName;
  bool get isAdmin;
  Stream<List<StoreConversation>> watchConversations();
  Stream<StoreConversation?> watchConversation(String customerId);
  Stream<List<StoreChatMessage>> watchMessages(String customerId);
  Future<void> sendMessage(
    String customerId,
    String text, {
    ChatAttachmentDraft? attachment,
  });
  Future<Uint8List> loadAttachment(String customerId, StoreChatMessage message);
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
  Future<void> sendMessage(
    String customerId,
    String text, {
    ChatAttachmentDraft? attachment,
  }) async {
    final error = chatMessageError(text, hasAttachment: attachment != null);
    if (error != null) throw ArgumentError(error);
    if (!isAdmin && customerId != currentUserId) {
      throw StateError('You can only send messages in your own conversation.');
    }
    final conversation = _conversations.doc(customerId);
    final message = conversation
        .collection('messages')
        .doc(attachment?.messageId);
    Reference? upload;
    ChatAttachment? stored;
    if (attachment != null) {
      final validation = chatAttachmentError(
        attachment.fileName,
        attachment.size,
      );
      if (validation != null) throw ArgumentError(validation);
      final path = chatAttachmentPath(
        storeId,
        customerId,
        currentUserId,
        message.id,
      );
      stored = attachment.storedAt(path);
      upload = FirebaseStorage.instance.ref(path);
      final existingMessage = await message.get(
        const GetOptions(source: Source.server),
      );
      if (existingMessage.exists) {
        final previous = StoreChatMessage.fromData(
          message.id,
          existingMessage.data()!,
        );
        if (previous.senderId == currentUserId &&
            previous.attachment?.storagePath == path) {
          return;
        }
        throw StateError('Please choose the attachment again.');
      }
    }
    try {
      if (upload != null && attachment != null) {
        var exists = false;
        try {
          final metadata = await upload.getMetadata();
          if (metadata.size != attachment.size ||
              metadata.contentType != attachment.contentType) {
            throw StateError('Please choose the attachment again.');
          }
          exists = true;
        } on FirebaseException catch (failure) {
          if (failure.code != 'object-not-found') rethrow;
        }
        if (!exists) {
          final bytes = await attachment.file.readAsBytes();
          if (bytes.length != attachment.size) {
            throw StateError('This file changed. Please choose it again.');
          }
          await upload.putData(
            bytes,
            SettableMetadata(
              contentType: attachment.contentType,
              customMetadata: {
                'senderId': currentUserId,
                'customerId': customerId,
                'messageId': message.id,
              },
            ),
          );
        }
      }
      await _db.runTransaction((transaction) async {
        if (attachment != null) {
          final previous = await transaction.get(message);
          if (previous.exists) return;
        }
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
          if (stored != null) 'attachment': stored.toData(),
        });
        transaction.set(conversation, {
          if (!existing.exists) ...{
            'storeId': storeId,
            'customerId': customerId,
            'adminReadAt': null,
          },
          if (!isAdmin) 'customerName': name,
          'lastMessageId': message.id,
          'lastMessage': chatMessagePreview(text, stored),
          'lastMessageAt': timestamp,
          'lastSenderId': currentUserId,
          'lastSenderRole': role,
          isAdmin ? 'adminReadAt' : 'customerReadAt': timestamp,
        }, SetOptions(merge: true));
      });
    } catch (_) {
      if (upload != null) {
        try {
          await upload.delete();
        } catch (_) {
          /* Published attachments remain immutable. */
        }
      }
      rethrow;
    }
  }

  @override
  Future<Uint8List> loadAttachment(
    String customerId,
    StoreChatMessage message,
  ) async {
    final attachment = message.attachment;
    if ((!isAdmin && customerId != currentUserId) ||
        attachment == null ||
        attachment.storagePath !=
            chatAttachmentPath(
              storeId,
              customerId,
              message.senderId,
              message.id,
            )) {
      throw StateError('This attachment is unavailable.');
    }
    final bytes = await FirebaseStorage.instance
        .ref(attachment.storagePath)
        .getData(chatAttachmentMaxBytes);
    if (bytes == null || bytes.length != attachment.size) {
      throw StateError('This attachment is unavailable.');
    }
    return bytes;
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
