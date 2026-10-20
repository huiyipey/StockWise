import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_models.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/stockwise_ui.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const StockWiseHeader(
            title: 'Notifications',
            leading: BackCircleButton(),
          ),
          Expanded(
            child: StreamBuilder<List<AppNotification>>(
              stream: FirestoreService.instance.watchNotifications(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Could not load notifications: ${snapshot.error}',
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final notices = snapshot.data!
                    .where(
                      (notice) => '${notice.title} ${notice.body}'
                          .toLowerCase()
                          .contains(query.toLowerCase()),
                    )
                    .toList();
                return ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    AppSearchField(
                      hint: 'Search notifications',
                      onChanged: (value) => setState(() => query = value),
                    ),
                    const SizedBox(height: 16),
                    if (notices.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(child: Text('No notifications yet.')),
                      ),
                    ...notices.map(_card),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

  Widget _card(AppNotification notice) {
    final color = notice.type == 'expiry_warning'
        ? AppColors.warning
        : notice.type == 'order_status'
        ? AppColors.blue
        : AppColors.primaryDark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: notice.readAt == null ? color.withValues(alpha: .06) : null,
        child: ListTile(
          contentPadding: const EdgeInsets.all(13),
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: .13),
            child: Icon(_icon(notice.type), color: color),
          ),
          title: Text(
            notice.title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            '${notice.body}\n${DateFormat('dd MMM, HH:mm').format(notice.createdAt)}',
          ),
          isThreeLine: true,
          onTap: notice.readAt == null
              ? () => FirestoreService.instance.markNotificationRead(notice.id)
              : null,
        ),
      ),
    );
  }

  IconData _icon(String type) => switch (type) {
    'expiry_warning' => Icons.warning_amber_rounded,
    'order_status' => Icons.receipt_long_outlined,
    'stock_consumed' => Icons.inventory_2_outlined,
    _ => Icons.notifications_outlined,
  };
}
