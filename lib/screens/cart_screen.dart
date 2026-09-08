import 'package:flutter/material.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(context),
              _buildContent(context),
            ],
          ),
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
            left: 22,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
              ),
            ),
          ),
          const Center(
            child: Text(
              'Cart',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildContent(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
          ),
        ),
        child: Column(
          children: [
            _buildCartItem(),
            _buildCartItem(),
            const SizedBox(height: 14),
            _buildSubtotal(),
            const SizedBox(height: 90),
            _buildCheckoutButton(context),
          ],
        ),
      ),
    );
  }

  static Widget _buildCartItem() {
    return Container(
      padding: const EdgeInsets.only(bottom: 26),
      margin: const EdgeInsets.only(bottom: 26),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E5E5), width: 1.5),
        ),
      ),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.inventory_2_outlined,
                      size: 28, color: Color(0xFFB5B5B5)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Product Name',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Exp: DD/MM/YYYY',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF888888),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 105,
                      height: 38,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCCCCCC), width: 1.5),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text('−',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111111))),
                          Text('1',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111111))),
                          Text('＋',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111111))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'RM 20.50',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(height: 34),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildSubtotal() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Subtotal',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111111),
            ),
          ),
          Text(
            'RM 41.00',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111111),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildCheckoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 62,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CheckoutScreen()),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7FAA75),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          shadowColor: const Color(0xFF7FAA75).withValues(alpha: 0.3),
        ),
        child: const Text(
          'CHECKOUT',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
