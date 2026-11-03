import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/store_chat.dart';
import '../services/store_chat_service.dart';
import '../widgets/inventory_ui.dart';
import '../widgets/profile_ui.dart';
import '../widgets/profile_tag.dart';
import 'store_chat_screen.dart';

class StoreChatInboxScreen extends StatefulWidget {
  const StoreChatInboxScreen({super.key, required this.repository});
  final StoreChatRepository repository;
  @override
  State<StoreChatInboxScreen> createState() => _StoreChatInboxScreenState();
}

class _StoreChatInboxScreenState extends State<StoreChatInboxScreen> {
  late final conversations = widget.repository.watchConversations();
  @override
  Widget build(BuildContext context) => InventoryTheme(
    child: Builder(
      builder: (context) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              InventoryHeader(
                title: 'Customer Messages',
                back: true,
                onBack: () => Navigator.maybePop(context),
              ),
              Expanded(
                child: StreamBuilder<List<StoreConversation>>(
                  stream: conversations,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: SingleChildScrollView(
                          child: ProfileEmpty(
                            'Could not load conversations',
                            body: 'Check your connection and reopen this page.',
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }
                    final rows = snapshot.data!;
                    if (rows.isEmpty) {
                      return const Center(
                        child: ProfileEmpty(
                          'No messages yet',
                          body: 'New messages will appear here.',
                          icon: Icons.chat_bubble_outline_rounded,
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        final unread = row.hasUnread(isAdmin: true);
                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
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
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ProfilePhoto(
                                    name: row.customerName,
                                    radius: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          row.customerName,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: unread
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${row.lastSenderRole == 'admin' ? 'Admin: ' : ''}${row.lastMessage}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            height: 1.4,
                                            color: InventoryColors.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (row.lastMessageAt != null)
                                        Text(
                                          DateFormat(
                                            'd MMM\nh:mm a',
                                          ).format(row.lastMessageAt!),
                                          textAlign: TextAlign.end,
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            color: InventoryColors.muted,
                                          ),
                                        ),
                                      if (unread) ...[
                                        const SizedBox(height: 10),
                                        const ProfileTag('Unread'),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
