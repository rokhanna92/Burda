import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/edition.dart';
import '../theme/typography.dart';
import 'page_furniture.dart';

/// A photo from the vault, on the diagonal hatch the design puts behind it.
///
/// The hatch is not decoration for its own sake: it is what shows while the
/// file loads, and what is left if the file has gone, so a missing photo reads
/// as an empty frame rather than a broken one.
class PhotoTile extends StatelessWidget {
  const PhotoTile({
    super.key,
    required this.edition,
    required this.path,
    this.placeholder,
    this.onRemove,
  });

  final Edition edition;

  /// Absolute path of the file. Null leaves the hatch showing.
  final String? path;

  /// Small monospace label on the hatch, behind the photo.
  final String? placeholder;

  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(color: edition.inkAt(12), blurRadius: 0, spreadRadius: 1),
        ],
      ),
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _HatchPainter(
                background: edition.tint,
                line: edition.hatch,
              ),
            ),
            if (placeholder != null)
              Padding(
                padding: const EdgeInsets.all(6),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    placeholder!,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontFamilyFallback: const ['Menlo', 'Courier'],
                      fontSize: 10,
                      letterSpacing: 0.4,
                      color: edition.inkAt(70),
                    ),
                  ),
                ),
              ),
            if (path != null)
              Image.file(
                File(path!),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            if (onRemove != null)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onRemove,
                  child: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: edition.ink,
                    ),
                    child: Text(
                      '×',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1,
                        color: edition.paper,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The dashed block at the end of a grid of photos, which asks for one more.
///
/// Lives here rather than on the issue screen because three grids now end with
/// it and they do not all mean the same thing by it: the vault takes a photo of
/// something she made, the contents take a photograph of a page.
class AddPhotoTile extends StatelessWidget {
  const AddPhotoTile({
    super.key,
    required this.edition,
    required this.onTap,
    this.glyph = '+',
    this.label = 'Add photo',
  });

  final Edition edition;

  /// Null while a picker is already open, which greys the block out.
  final VoidCallback? onTap;

  final String glyph;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: CustomPaint(
        painter: DashedBorder(colour: edition.inkAt(45)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              glyph,
              style: AppType.serif(
                size: 30,
                weight: 300,
                height: 1,
                color: edition.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppType.smallCaps(
                size: 12,
                trackingEm: 0.14,
                color: edition.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The design's `repeating-linear-gradient(135deg, tint 0 6px, hatch 6px 7px)`.
///
/// Flutter has no repeating gradient, and faking one with a tiled shader gets
/// the period wrong on non-square tiles, so the stripes are drawn directly:
/// hairlines at 45 degrees, one every 7 logical pixels.
class _HatchPainter extends CustomPainter {
  const _HatchPainter({required this.background, required this.line});

  final Color background;
  final Color line;

  static const double _period = 7;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);

    final reach = math.sqrt(
      size.width * size.width + size.height * size.height,
    );
    final stroke = Paint()
      ..color = line
      ..strokeWidth = 1;

    canvas.save();
    canvas.rotate(math.pi / 4);
    for (var x = -reach; x <= reach; x += _period) {
      canvas.drawLine(Offset(x, -reach), Offset(x, reach), stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HatchPainter oldDelegate) =>
      oldDelegate.background != background || oldDelegate.line != line;
}
