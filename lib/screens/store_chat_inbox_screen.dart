import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/store_chat.dart';
import '../services/store_chat_service.dart';
import 'store_chat_screen.dart';

class StoreChatInboxScreen extends StatefulWidget {
  final StoreChatRepository repository;
  const StoreChatInboxScreen({super.key, required this.repository});

  @override
  State<StoreChatInboxScreen> createState() => _StoreChatInboxScreenState();
}

class _StoreChatInboxScreenState extends State<StoreChatInboxScreen> {
  late final conversations = widget.repository.watchConversations();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Customer messages')),
    body: StreamBuilder<List<StoreConversation>>(
      stream: conversations,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Could not load conversations. Check your connection and reopen this page.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snapshot.data!;
        if (rows.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Customer conversations will appear here when they send their first message.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final row = rows[index];
            final unread = row.hasUnread(isAdmin: true);
            return ListTile(
              leading: Badge(
                isLabelVisible: unread,
                child: const CircleAvatar(child: Icon(Icons.person_outline)),
              ),
              title: Text(
                row.customerName,
                style: TextStyle(
                  fontWeight: unread ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
              subtitle: Text(
                '${row.lastSenderRole == 'admin' ? 'Admin: ' : ''}${row.lastMessage}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (row.lastMessageAt != null)
                    Text(
                      DateFormat('d MMM, h:mm a').format(row.lastMessageAt!),
                      style: const TextStyle(fontSize: 11),
                    ),
                  if (unread)
                    const Text(
                      'Unread',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StoreChatScreen(
                    repository: widget.repository,
                    customerId: row.customerId,
                    customerName: row.customerName,
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
