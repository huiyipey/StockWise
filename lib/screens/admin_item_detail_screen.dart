import 'package:flutter/material.dart';

class AdminItemDetailScreen extends StatelessWidget {
  const AdminItemDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(context),
              _buildImageCard(),
              _buildContent(),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 150,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      decoration: const BoxDecoration(color: Color(0xFF7FAA75)),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
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
              'Milk',
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

  static Widget _buildImageCard() {
    return Transform.translate(
      offset: const Offset(0, -85),
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(16),
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
          child: Container(
            height: 220,
            decoration: BoxDecoration(
              color: const Color(0xFFEFEFEF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
            ),
            child: const Center(
              child: Icon(Icons.image_outlined, size: 70, color: Color(0xFF888888)),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildContent() {
    return Transform.translate(
      offset: const Offset(0, -45),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 65, 24, 36),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFDF2F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time, size: 18, color: Color(0xFFD9534F)),
                  SizedBox(width: 8),
                  Text(
                    'Expiry Date: 15/10/2024',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD9534F),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildField('Quantity:', '1 gallon'),
            const SizedBox(height: 18),
            _buildCategoryField(),
            const SizedBox(height: 44),
            _buildButtonGroup(),
            const SizedBox(height: 36),
            _buildDeleteIcon(),
          ],
        ),
      ),
    );
  }

  static Widget _buildField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF666666),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF888888),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static Widget _buildCategoryField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF666666),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF888888),
                ),
              ),
              Icon(Icons.arrow_drop_down, size: 24, color: Color(0xFF888888)),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _buildButtonGroup() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 58,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7FAA75),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 4,
                shadowColor: const Color(0xFF7FAA75).withValues(alpha: 0.3),
              ),
              child: const Text(
                'Mark as Consumed',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 130,
          height: 58,
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0B5C88),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 4,
              shadowColor: const Color(0xFF0B5C88).withValues(alpha: 0.3),
            ),
            child: const Text(
              'Edit Item',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  static Widget _buildDeleteIcon() {
    return Center(
      child: GestureDetector(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.delete_outline, size: 28, color: Color(0xFFC4C4C4)),
        ),
      ),
    );
  }
}
