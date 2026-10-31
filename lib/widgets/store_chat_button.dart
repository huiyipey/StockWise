import 'package:flutter/material.dart';

import '../models/store_chat.dart';
import '../screens/store_chat_inbox_screen.dart';
import '../screens/store_chat_screen.dart';
import '../services/store_chat_service.dart';
import 'inventory_ui.dart' show InventoryColors;

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
  final bool inventoryStyle;
  const StoreChatButton({
    super.key,
    this.repository,
    this.inventoryStyle = false,
  });

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
          style: widget.inventoryStyle
              ? IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: InventoryColors.green,
                  shape: const CircleBorder(),
                  minimumSize: const Size.square(40),
                )
              : null,
          icon: Icon(
            Icons.chat_bubble_outline_rounded,
            color: widget.inventoryStyle ? InventoryColors.green : Colors.white,
            size: widget.inventoryStyle ? 20 : null,
          ),
        ),
      );
    },
  );
}
