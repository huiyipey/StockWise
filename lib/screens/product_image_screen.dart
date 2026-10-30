import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProductImageScreen extends StatefulWidget {
  final ImageProvider image;
  final String title;
  final bool inventoryStyle;

  const ProductImageScreen({
    super.key,
    required this.image,
    required this.title,
    this.inventoryStyle = false,
  });

  @override
  State<ProductImageScreen> createState() => _ProductImageScreenState();
}

class _ProductImageScreenState extends State<ProductImageScreen> {
  static const maxScale = 6.0;
  final transformation = TransformationController();
  Size viewport = Size.zero;
  Offset doubleTapPosition = Offset.zero;
  int reload = 0;

  @override
  void dispose() {
    transformation.dispose();
    super.dispose();
  }

  void _zoomTo(double scale, Offset focalPoint) {
    final next = scale.clamp(1.0, maxScale);
    if (next == 1) {
      transformation.value = Matrix4.identity();
      return;
    }
    final point = transformation.toScene(focalPoint);
    final x = (focalPoint.dx - point.dx * next).clamp(
      viewport.width * (1 - next),
      0.0,
    );
    final y = (focalPoint.dy - point.dy * next).clamp(
      viewport.height * (1 - next),
      0.0,
    );
    transformation.value = Matrix4.identity()
      ..setEntry(0, 0, next)
      ..setEntry(1, 1, next)
      ..setEntry(0, 3, x)
      ..setEntry(1, 3, y);
  }

  void _stepZoom(double factor) => _zoomTo(
    transformation.value.getMaxScaleOnAxis() * factor,
    Offset(viewport.width / 2, viewport.height / 2),
  );

  Future<void> _retry() async {
    await widget.image.evict();
    if (mounted) {
      transformation.value = Matrix4.identity();
      setState(() => reload++);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: widget.inventoryStyle
        ? const Color(0xFF1B2D24)
        : Colors.black,
    appBar: AppBar(
      backgroundColor: widget.inventoryStyle
          ? const Color(0xFF1B2D24)
          : Colors.black,
      foregroundColor: Colors.white,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leadingWidth: widget.inventoryStyle ? 70 : null,
      titleSpacing: widget.inventoryStyle ? 0 : null,
      leading: Padding(
        padding: widget.inventoryStyle
            ? const EdgeInsets.fromLTRB(20, 8, 8, 8)
            : EdgeInsets.zero,
        child: IconButton(
          tooltip: 'Close image',
          style: widget.inventoryStyle
              ? IconButton.styleFrom(backgroundColor: const Color(0xFF334A3C))
              : null,
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      title: Text(
        widget.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: widget.inventoryStyle
            ? const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)
            : null,
      ),
    ),
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                viewport = constraints.biggest;
                return GestureDetector(
                  onDoubleTapDown: (details) =>
                      doubleTapPosition = details.localPosition,
                  onDoubleTap: () => _zoomTo(
                    transformation.value.getMaxScaleOnAxis() > 1 ? 1 : 2.5,
                    doubleTapPosition,
                  ),
                  child: InteractiveViewer(
                    transformationController: transformation,
                    minScale: 1,
                    maxScale: maxScale,
                    child: SizedBox(
                      width: viewport.width,
                      height: viewport.height,
                      child: Image(
                        key: ValueKey(reload),
                        image: widget.image,
                        width: widget.inventoryStyle
                            ? viewport.width - 40
                            : null,
                        fit: BoxFit.contain,
                        semanticLabel: widget.title,
                        frameBuilder: (context, child, frame, synchronous) =>
                            frame != null || synchronous
                            ? widget.inventoryStyle
                                  ? Center(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: child,
                                      ),
                                    )
                                  : child
                            : const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                        errorBuilder: (context, error, stack) => Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white70,
                                size: 44,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Could not load this image.',
                                style: TextStyle(color: Colors.white),
                              ),
                              TextButton(
                                onPressed: _retry,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (!widget.inventoryStyle)
            ValueListenableBuilder<Matrix4>(
              valueListenable: transformation,
              builder: (context, matrix, _) {
                final scale = matrix.getMaxScaleOnAxis();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Zoom out',
                      color: Colors.white,
                      disabledColor: Colors.white38,
                      onPressed: scale > 1 ? () => _stepZoom(1 / 1.5) : null,
                      icon: const Icon(Icons.zoom_out_rounded),
                    ),
                    TextButton(
                      onPressed: () =>
                          transformation.value = Matrix4.identity(),
                      child: const Text(
                        'Reset',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Zoom in',
                      color: Colors.white,
                      disabledColor: Colors.white38,
                      onPressed: scale < maxScale ? () => _stepZoom(1.5) : null,
                      icon: const Icon(Icons.zoom_in_rounded),
                    ),
                  ],
                );
              },
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              widget.inventoryStyle ? 38 : 12,
            ),
            child: Text(
              widget.inventoryStyle
                  ? 'Pinch to zoom. Drag to move.'
                  : 'Pinch to zoom • Double-tap to enlarge or reset',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: widget.inventoryStyle
                    ? const Color(0xFFCAD9CB)
                    : Colors.white70,
                fontSize: widget.inventoryStyle ? 12 : null,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
