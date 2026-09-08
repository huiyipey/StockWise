import 'package:flutter/material.dart';

class AddItemScreen extends StatelessWidget {
  const AddItemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              _buildPhotoCard(),
              _buildFormPanel(),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 250,
      decoration: const BoxDecoration(color: Color(0xFF79AD74)),
      child: Stack(
        children: [
          const Center(
            child: Text(
              'Add New Item',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 80,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildPhotoCard() {
    return Transform.translate(
      offset: const Offset(0, -175),
      child: Center(
        child: Container(
          width: 320,
          height: 180,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F1F1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt_outlined, size: 48, color: Color(0xFF777777)),
                SizedBox(height: 10),
                Text(
                  'Upload Photo',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF333333),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildFormPanel() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 36),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          _buildTextField('Name'),
          const SizedBox(height: 16),
          _buildDateField(),
          const SizedBox(height: 16),
          _buildQuantityField(),
          const SizedBox(height: 16),
          _buildCategoryField(),
          const SizedBox(height: 32),
          _buildNotificationRow(),
          const SizedBox(height: 40),
          _buildSaveButton(),
        ],
      ),
    );
  }

  static Widget _buildTextField(String hint) {
    return Container(
      width: double.infinity,
      height: 62,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFF777777),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        style: const TextStyle(
          color: Color(0xFF444444),
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  static Widget _buildDateField() {
    return Container(
      width: double.infinity,
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.calendar_today, size: 20, color: Color(0xFF777777)),
          SizedBox(width: 14),
          Text(
            'DD/MM/YYYY',
            style: TextStyle(
              color: Color(0xFF444444),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildQuantityField() {
    return Container(
      width: double.infinity,
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Quantity',
            style: TextStyle(
              color: Color(0xFF777777),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          Row(
            children: [
              Icon(Icons.remove_circle_outline,
                  size: 28, color: Color(0xFF555555)),
              SizedBox(width: 12),
              Text('1',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF444444))),
              SizedBox(width: 12),
              Icon(Icons.add_circle_outline,
                  size: 28, color: Color(0xFF7FAA75)),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildCategoryField() {
    return Container(
      width: double.infinity,
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Category',
            style: TextStyle(
              color: Color(0xFF777777),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          Row(
            children: [
              Text(
                'Select',
                style: TextStyle(
                  color: Color(0xFFAAAAAA),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.arrow_drop_down,
                  size: 24, color: Color(0xFFAAAAAA)),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildNotificationRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Row(
          children: [
            Icon(Icons.notifications_outlined, size: 22, color: Color(0xFF777777)),
            SizedBox(width: 12),
            Text(
              'Receive Notifications',
              style: TextStyle(
                color: Color(0xFF777777),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        Container(
          width: 56,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF7656B5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.all(4),
              child: CircleAvatar(
                radius: 12,
                backgroundColor: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  static Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 62,
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF79AD74),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 4,
          shadowColor: const Color(0xFF79AD74).withValues(alpha: 0.3),
        ),
        child: const Text(
          'Save Item',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
