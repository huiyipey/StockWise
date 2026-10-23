import 'package:flutter/material.dart';

class ProductImageScreen extends StatefulWidget {
  final ImageProvider image;
  final String title;

  const ProductImageScreen({
    super.key,
    required this.image,
    required this.title,
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
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      leading: IconButton(
        tooltip: 'Close image',
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.close_rounded),
      ),
      title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
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
                        fit: BoxFit.contain,
                        semanticLabel: widget.title,
                        frameBuilder: (context, child, frame, synchronous) =>
                            frame != null || synchronous
                            ? child
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
                    onPressed: () => transformation.value = Matrix4.identity(),
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Pinch to zoom • Double-tap to enlarge or reset',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    ),
  );
}
