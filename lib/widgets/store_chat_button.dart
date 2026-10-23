import 'package:flutter/material.dart';

import '../models/store_chat.dart';
import '../screens/store_chat_inbox_screen.dart';
import '../screens/store_chat_screen.dart';
import '../services/store_chat_service.dart';

void openStoreChat(BuildContext context, {StoreChatRepository? repository}) {
  final chat = repository ?? StoreChatService.forSelectedStore();
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => chat.isAdmin
          ? StoreChatInboxScreen(repository: chat)
          : StoreChatScreen(repository: chat, customerId: chat.currentUserId),
    ),
  );
}

class StoreChatButton extends StatefulWidget {
  final StoreChatRepository? repository;
  const StoreChatButton({super.key, this.repository});

  @override
  State<StoreChatButton> createState() => _StoreChatButtonState();
}

class _StoreChatButtonState extends State<StoreChatButton> {
  late final repository =
      widget.repository ?? StoreChatService.forSelectedStore();
  late final conversations = repository.watchConversations();

  @override
  Widget build(BuildContext context) => StreamBuilder<List<StoreConversation>>(
    stream: conversations,
    builder: (context, snapshot) {
      final unread =
          snapshot.data
              ?.where((row) => row.hasUnread(isAdmin: repository.isAdmin))
              .length ??
          0;
      return Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: IconButton(
          tooltip: repository.isAdmin ? 'Customer messages' : 'Chat with admin',
          onPressed: () => openStoreChat(context, repository: repository),
          icon: const Icon(
            Icons.chat_bubble_outline_rounded,
            color: Colors.white,
          ),
        ),
      );
    },
  );
}
