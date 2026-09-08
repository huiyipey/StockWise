import 'package:flutter/material.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              _buildProfileCard(context),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: const BoxDecoration(color: Color(0xFF7FAA75)),
      child: Stack(
        children: [
          const Center(
            child: Text(
              'My Profile',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Positioned(
            right: 20,
            top: 24,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit_outlined, color: Colors.black, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildProfileCard(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -15),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 36, 24, 50),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(22),
            topRight: Radius.circular(22),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFEFEFEF), width: 4),
                color: const Color(0xFFFAFAFA),
              ),
              child: const Center(
                child: Icon(Icons.person_outline, size: 50, color: Color(0xFF666666)),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Name',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Color(0xFF222222),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'testingstock@gmail.com',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF777777),
              ),
            ),
            const SizedBox(height: 36),
            _buildMenuItem(Icons.settings_outlined, 'Account Settings'),
            const SizedBox(height: 16),
            _buildMenuItem(Icons.history, 'Order History'),
            const SizedBox(height: 16),
            _buildNotificationRow(),
            const SizedBox(height: 60),
            _buildLogoutButton(context),
          ],
        ),
      ),
    );
  }

  static Widget _buildMenuItem(IconData icon, String label) {
    return Container(
      width: double.infinity,
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: const Color(0xFF333333)),
          ),
          const SizedBox(width: 16),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
          const Spacer(),
          const Icon(Icons.chevron_right, size: 24, color: Color(0xFFAAAAAA)),
        ],
      ),
    );
  }

  static Widget _buildNotificationRow() {
    return Container(
      width: double.infinity,
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_outlined, size: 22, color: Color(0xFF333333)),
              SizedBox(width: 16),
              Text(
                'Receive Notifications',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          _ToggleSwitch(),
        ],
      ),
    );
  }

  static Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 62,
      child: ElevatedButton(
        onPressed: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEF5A5F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
        ),
        child: const Text(
          'LOG OUT',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ToggleSwitch extends StatelessWidget {
  const _ToggleSwitch();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 30,
      decoration: BoxDecoration(
        color: const Color(0xFF7B58C5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: EdgeInsets.all(4),
          child: CircleAvatar(
            radius: 11,
            backgroundColor: Colors.white,
          ),
        ),
      ),
    );
  }
}
