import 'package:flutter/material.dart';

import '../screens/product_image_screen.dart';
import '../services/firestore_service.dart';
import 'inventory_ui.dart';
import 'order_ui.dart';

class OrderReceipt extends StatefulWidget {
  const OrderReceipt({
    super.key,
    required this.orderNumber,
    required this.isAdmin,
    this.path,
    this.busy = false,
    this.onUpload,
    this.imageResolver,
  });
  final String orderNumber;
  final bool isAdmin, busy;
  final String? path;
  final VoidCallback? onUpload;
  final Future<ImageProvider> Function(String)? imageResolver;
  @override
  State<OrderReceipt> createState() => _OrderReceiptState();
}

class _OrderReceiptState extends State<OrderReceipt> {
  Future<ImageProvider>? image;
  int revision = 0;
  bool get uploaded => widget.path?.trim().isNotEmpty == true;
  @override
  void initState() {
    super.initState();
    resolve();
  }

  @override
  void didUpdateWidget(covariant OrderReceipt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path != oldWidget.path) resolve();
  }

  void resolve() {
    image = uploaded
        ? (widget.imageResolver ?? defaultImage)(widget.path!)
        : null;
  }

  Future<ImageProvider> defaultImage(String path) async => NetworkImage(
    path.startsWith('http')
        ? path
        : (await FirestoreService.instance.imageUrl(path))!,
  );
  void retry() => setState(() {
    revision++;
    resolve();
  });

  @override
  Widget build(BuildContext context) => OrderPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!uploaded)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(
              children: [
                Icon(
                  widget.isAdmin
                      ? Icons.description_outlined
                      : Icons.attach_file_rounded,
                  size: 30,
                  color: InventoryColors.muted,
                ),
                const SizedBox(height: 14),
                const Text(
                  'No payment receipt uploaded yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: InventoryColors.muted,
                  ),
                ),
              ],
            ),
          )
        else ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 180,
              color: InventoryColors.background,
              child: FutureBuilder<ImageProvider>(
                future: image,
                builder: (context, snapshot) {
                  if (snapshot.hasError) return failure();
                  if (!snapshot.hasData) return const _ReceiptLoading();
                  return Tooltip(
                    message: 'Enlarge receipt',
                    child: InkWell(
                      key: const ValueKey('receipt-preview'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (_) => ProductImageScreen(
                            image: snapshot.data!,
                            title: 'Payment Receipt',
                            subtitle: '#${widget.orderNumber}',
                            receiptStyle: true,
                          ),
                        ),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image(
                            key: ValueKey(revision),
                            image: snapshot.data!,
                            fit: BoxFit.contain,
                            semanticLabel:
                                'Payment receipt for ${widget.orderNumber}',
                            frameBuilder:
                                (context, child, frame, synchronous) =>
                                    synchronous || frame != null
                                    ? child
                                    : const _ReceiptLoading(),
                            errorBuilder: (_, _, _) => failure(),
                          ),
                          const Positioned(
                            right: 10,
                            bottom: 10,
                            child: CircleAvatar(
                              radius: 17,
                              backgroundColor: Colors.white,
                              child: Icon(
                                Icons.open_in_full_rounded,
                                size: 18,
                                color: InventoryColors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Center(child: OrderBadge('Receipt uploaded')),
        ],
        if (!widget.isAdmin) ...[
          const SizedBox(height: 16),
          InventoryButton(
            label: widget.busy
                ? 'Uploading...'
                : uploaded
                ? 'Replace receipt'
                : 'Upload receipt',
            icon: Icons.image_outlined,
            soft: true,
            busy: widget.busy,
            onPressed: widget.onUpload,
          ),
        ],
      ],
    ),
  );

  Widget failure() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.broken_image_outlined,
          size: 28,
          color: InventoryColors.muted,
        ),
        const SizedBox(height: 10),
        const Text(
          'Could not load receipt',
          style: TextStyle(fontSize: 12, color: InventoryColors.muted),
        ),
        TextButton(onPressed: retry, child: const Text('Retry')),
      ],
    ),
  );
}

class _ReceiptLoading extends StatelessWidget {
  const _ReceiptLoading();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(height: 14),
        Text(
          'Loading receipt...',
          style: TextStyle(fontSize: 12, color: InventoryColors.muted),
        ),
      ],
    ),
  );
}
