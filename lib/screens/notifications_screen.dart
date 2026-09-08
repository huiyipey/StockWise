import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildSearchBar(),
            _buildNotificationList(),
          ],
        ),
      ),
    );
  }

  static Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 130,
      decoration: const BoxDecoration(color: Color(0xFF7FAA75)),
      child: Stack(
        children: [
          Positioned(
            left: 20,
            top: 22,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
              ),
            ),
          ),
          const Center(
            child: Text(
              'Notifications',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Transform.translate(
        offset: const Offset(0, -22),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(Icons.search, size: 22, color: Color(0xFFAAAAAA)),
              SizedBox(width: 12),
              Text(
                'Search notifications...',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFFAAAAAA),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildNotificationList() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
        child: ListView(
          children: [
            _buildNotificationCard(Icons.warning_amber_rounded, 'Milk expiring in 7 days', 'Just now', const Color(0xFFD6A03A)),
            const SizedBox(height: 14),
            _buildNotificationCard(Icons.error_outline, 'Chicken expiring tomorrow!', 'Just now', const Color(0xFFD9534F)),
            const SizedBox(height: 14),
            _buildNotificationCard(Icons.check_circle_outline, 'Yogurt marked as consumed', 'Just now', const Color(0xFF5AA05A)),
            const SizedBox(height: 14),
            _buildNotificationCard(Icons.check_circle_outline, 'Eggs marked as consumed', 'Just now', const Color(0xFF5AA05A)),
            const SizedBox(height: 14),
            _buildNotificationCard(Icons.warning_amber_rounded, 'Eggs expiring in 3 days', 'Yesterday', const Color(0xFFD6A03A)),
          ],
        ),
      ),
    );
  }

  static Widget _buildNotificationCard(IconData icon, String title, String time, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF222222),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
