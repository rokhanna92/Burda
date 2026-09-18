import 'dart:math';

import 'package:flutter/material.dart';

/// Hearts falling across the whole screen, swaying as they go.
///
/// The original app shipped this effect but nothing in the recovered code says
/// what set it off, so here it marks the collection being completed.
class RainingHearts extends StatefulWidget {
  const RainingHearts({
    super.key,
    this.count = 26,
    this.duration = const Duration(seconds: 4),
    this.onFinished,
  });

  final int count;
  final Duration duration;
  final VoidCallback? onFinished;

  @override
  State<RainingHearts> createState() => _RainingHeartsState();
}

class _RainingHeartsState extends State<RainingHearts>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: widget.duration,
    vsync: this,
  );

  // Fixed per heart, so each one falls its own way.
  late final List<double> _xPositions;
  late final List<double> _speeds;
  late final List<double> _swayOffsets;
  late final List<double> _sizes;
  late final List<double> _starts;

  @override
  void initState() {
    super.initState();
    final random = Random(7);
    _xPositions = [
      for (var i = 0; i < widget.count; i++) random.nextDouble(),
    ];
    _speeds = [
      for (var i = 0; i < widget.count; i++) 0.7 + random.nextDouble() * 0.6,
    ];
    _swayOffsets = [
      for (var i = 0; i < widget.count; i++) random.nextDouble() * pi * 2,
    ];
    _sizes = [
      for (var i = 0; i < widget.count; i++) 18 + random.nextDouble() * 22,
    ];
    _starts = [
      for (var i = 0; i < widget.count; i++) random.nextDouble() * 0.35,
    ];

    _controller.forward().whenComplete(() => widget.onFinished?.call());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = [scheme.primary, scheme.onSurface, const Color(0xFFF44336)];

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final area = Size(constraints.maxWidth, constraints.maxHeight);
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Stack(
              children: [
                for (var i = 0; i < widget.count; i++) _heart(i, area, colors),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _heart(int index, Size area, List<Color> colors) {
    // Each heart starts a little later and falls at its own speed.
    final progress =
        ((_controller.value - _starts[index]) * _speeds[index]).clamp(0.0, 1.0);
    if (progress <= 0) return const SizedBox.shrink();

    final sway = sin(progress * pi * 3 + _swayOffsets[index]) * 22;
    final size = _sizes[index];

    return Positioned(
      left: _xPositions[index] * (area.width - size) + sway,
      top: progress * (area.height + size) - size,
      child: Opacity(
        opacity: (1 - progress).clamp(0.0, 1.0) * 0.9 + 0.1,
        child: Icon(
          Icons.favorite,
          size: size,
          color: colors[index % colors.length],
        ),
      ),
    );
  }
}

/// Rains hearts over whatever is on screen, then clears them away.
void showRainingHearts(BuildContext context) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Positioned.fill(
      child: RainingHearts(onFinished: () => entry.remove()),
    ),
  );
  overlay.insert(entry);
}
