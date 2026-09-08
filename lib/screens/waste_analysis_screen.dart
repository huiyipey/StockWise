import 'dart:math' show pi;
import 'package:flutter/material.dart';
import '../widgets/glass_bottom_nav.dart';

class WasteAnalysisScreen extends StatelessWidget {
  const WasteAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(context),
                  _buildContent(),
                ],
              ),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  static Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 100,
      decoration: const BoxDecoration(color: Color(0xFF7FAA75)),
      child: Stack(
        children: [
          Positioned(
            left: 20,
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
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
              ),
            ),
          ),
          const Center(
            child: Text(
              'Waste Analysis',
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

  static Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
      child: Column(
        children: [
          _buildDonutCard(),
          const SizedBox(height: 24),
          _buildBarChartCard(),
        ],
      ),
    );
  }

  static Widget _buildDonutCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 200,
            height: 200,
            child: CustomPaint(
              painter: _DonutChartPainter(),
              child: const Center(
                child: SizedBox(
                  width: 90,
                  height: 90,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Waste Composition',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF444444),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildSummaryBox('25', 'Total Quantity')),
              const SizedBox(width: 14),
              Expanded(child: _buildSummaryBox('40', 'Total Category')),
            ],
          ),
          const SizedBox(height: 16),
          _buildLegendRow(),
        ],
      ),
    );
  }

  static Widget _buildLegendRow() {
    final legends = [
      (const Color(0xFF1F35FF), 'Dairy'),
      (const Color(0xFF1DB100), 'Vegetables'),
      (const Color(0xFFFFE600), 'Fruits'),
      (const Color(0xFFFF1E1E), 'Meat'),
      (const Color(0xFFF6A400), 'Others'),
    ];
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: legends.map((l) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: l.$1,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            l.$2,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF666666),
            ),
          ),
        ],
      )).toList(),
    );
  }

  static Widget _buildSummaryBox(String number, String label) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 1),
      ),
      child: Column(
        children: [
          Text(
            number,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF777777),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildBarChartCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Waste Generation',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF444444),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: CustomPaint(
              painter: _BarChartAxisPainter(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildBar(110, 'Jan'),
                    _buildBar(130, 'Feb'),
                    _buildBar(90, 'Mar'),
                    _buildBar(105, 'Apr'),
                    _buildBar(80, 'May'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildBar(double height, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: height,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color(0xFF4D77C4), Color(0xFF6B9BE6)],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF666666),
          ),
        ),
      ],
    );
  }

  static Widget _buildBottomNav() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: GlassBottomNav(
        currentIndex: 2,
        activeColor: const Color(0xFF5B4B9A),
        items: const [
          NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
          NavItem(icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2, label: 'Items'),
          NavItem(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart, label: 'Report'),
          NavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 50.0;
    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    final segments = [
      (color: const Color(0xFF1F35FF), start: 0.0, sweep: 0.30),
      (color: const Color(0xFF1DB100), start: 0.30, sweep: 0.15),
      (color: const Color(0xFFFFE600), start: 0.45, sweep: 0.13),
      (color: const Color(0xFFFF1E1E), start: 0.58, sweep: 0.20),
      (color: const Color(0xFFF6A400), start: 0.78, sweep: 0.22),
    ];

    for (final seg in segments) {
      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        rect,
        -pi / 2 + seg.start * 2 * pi,
        seg.sweep * 2 * pi,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BarChartAxisPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFDDDDDD)
      ..strokeWidth = 2;

    final leftX = 0.0;
    final bottomY = size.height;

    canvas.drawLine(Offset(leftX, 0), Offset(leftX, bottomY), paint);
    canvas.drawLine(Offset(leftX, bottomY), Offset(size.width, bottomY), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
