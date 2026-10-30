import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../widgets/inventory_ui.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.itf14,
      BarcodeFormat.codabar,
      BarcodeFormat.qrCode,
    ],
  );
  bool detected = false;
  bool unavailable = false;

  @override
  void initState() {
    super.initState();
    controller.addListener(_cameraStateChanged);
  }

  void _cameraStateChanged() {
    if (mounted && unavailable && controller.value.isRunning) {
      setState(() => unavailable = false);
    }
  }

  @override
  void dispose() {
    controller.removeListener(_cameraStateChanged);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => InventoryTheme(
    child: Builder(
      builder: (context) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              InventoryHeader(
                title: 'Scan barcode',
                back: true,
                onBack: () => Navigator.maybePop(context),
              ),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: const Color(0xFF23332C),
                      child: MobileScanner(
                        controller: controller,
                        onDetect: _onDetect,
                        errorBuilder: (context, error) {
                          if (!unavailable) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() => unavailable = true);
                            });
                          }
                          return const ScannerUnavailable();
                        },
                      ),
                    ),
                    if (!unavailable)
                      Center(
                        child: Container(
                          width: 290,
                          height: 170,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFFEDC879),
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    if (!unavailable)
                      const Positioned(
                        left: 24,
                        right: 24,
                        bottom: 38,
                        child: Card(
                          color: Colors.white,
                          child: Padding(
                            padding: EdgeInsets.all(14),
                            child: Text(
                              'Place the product barcode inside the frame.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  void _onDetect(BarcodeCapture capture) {
    if (detected) return;
    final value = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .firstOrNull;
    if (value == null) return;
    detected = true;
    Navigator.pop(context, value.trim());
  }
}

class ScannerUnavailable extends StatelessWidget {
  const ScannerUnavailable({super.key});
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFF23332C),
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(35),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 39,
              backgroundColor: Color(0xFF405348),
              child: Icon(
                Icons.qr_code_scanner_rounded,
                size: 42,
                color: Color(0xFFD2E1D2),
              ),
            ),
            SizedBox(height: 30),
            Text(
              'Camera unavailable',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 22),
            Text(
              'Return to the item form and enter the barcode manually.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFD2E1D2),
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
