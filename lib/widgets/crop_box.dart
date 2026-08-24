import 'dart:typed_data';
import 'package:flutter/material.dart';

/// A simple draggable rectangular crop overlay over an image.
///
/// Renders [imageBytes] at its natural aspect ratio and lets the user drag
/// the four corner handles (or the body, to reposition) to adjust a crop
/// rectangle. Reports the current rectangle back via [onChanged] normalized
/// to 0..1 of the image's own width/height, so the caller can apply it to
/// full-resolution pixel data.
class CropBox extends StatefulWidget {
  const CropBox({
    super.key,
    required this.imageBytes,
    required this.imageWidth,
    required this.imageHeight,
    required this.onChanged,
  });

  final Uint8List imageBytes;
  final int imageWidth;
  final int imageHeight;
  final ValueChanged<Rect> onChanged;

  @override
  State<CropBox> createState() => _CropBoxState();
}

class _CropBoxState extends State<CropBox> {
  Rect _rect = const Rect.fromLTRB(0.08, 0.08, 0.92, 0.92);
  static const double _handleTouchSize = 36;
  static const double _minSize = 0.12;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onChanged(_rect));
  }

  @override
  void didUpdateWidget(covariant CropBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageBytes != widget.imageBytes) {
      // New image (e.g. after a rotate) — reset to a fresh default crop.
      _rect = const Rect.fromLTRB(0.08, 0.08, 0.92, 0.92);
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onChanged(_rect));
    }
  }

  void _update(Rect newRect) {
    setState(() => _rect = newRect);
    widget.onChanged(newRect);
  }

  @override
  Widget build(BuildContext context) {
    final aspect = widget.imageWidth / widget.imageHeight;
    return AspectRatio(
      aspectRatio: aspect,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final px = _rect.left * size.width;
          final py = _rect.top * size.height;
          final pw = _rect.width * size.width;
          final ph = _rect.height * size.height;

          void dragCorner(DragUpdateDetails d, {required bool left, required bool top}) {
            final dx = d.delta.dx / size.width;
            final dy = d.delta.dy / size.height;
            double l = _rect.left, t = _rect.top, r = _rect.right, b = _rect.bottom;
            if (left) {
              l = (l + dx).clamp(0.0, r - _minSize);
            } else {
              r = (r + dx).clamp(l + _minSize, 1.0);
            }
            if (top) {
              t = (t + dy).clamp(0.0, b - _minSize);
            } else {
              b = (b + dy).clamp(t + _minSize, 1.0);
            }
            _update(Rect.fromLTRB(l, t, r, b));
          }

          Widget handle({required bool left, required bool top}) {
            return Positioned(
              left: (left ? px : px + pw) - _handleTouchSize / 2,
              top: (top ? py : py + ph) - _handleTouchSize / 2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) => dragCorner(d, left: left, top: top),
                child: Container(
                  width: _handleTouchSize,
                  height: _handleTouchSize,
                  alignment: Alignment.center,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black26),
                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
                    ),
                  ),
                ),
              ),
            );
          }

          return ClipRect(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Image.memory(
                  widget.imageBytes,
                  width: size.width,
                  height: size.height,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CropOverlayPainter(rect: Rect.fromLTWH(px, py, pw, ph)),
                  ),
                ),
                Positioned(
                  left: px,
                  top: py,
                  width: pw,
                  height: ph,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (d) {
                      final dx = d.delta.dx / size.width;
                      final dy = d.delta.dy / size.height;
                      final w = _rect.width, h = _rect.height;
                      final l = (_rect.left + dx).clamp(0.0, 1.0 - w);
                      final t = (_rect.top + dy).clamp(0.0, 1.0 - h);
                      _update(Rect.fromLTWH(l, t, w, h));
                    },
                    child: Container(
                      decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2)),
                    ),
                  ),
                ),
                handle(left: true, top: true),
                handle(left: false, top: true),
                handle(left: true, top: false),
                handle(left: false, top: false),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  _CropOverlayPainter({required this.rect});
  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final dim = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final path = Path.combine(
      PathOperation.difference,
      Path()..addRect(full),
      Path()..addRect(rect),
    );
    canvas.drawPath(path, dim);
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) => oldDelegate.rect != rect;
}
