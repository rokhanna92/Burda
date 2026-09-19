import 'package:flutter/material.dart';

import '../theme/edition.dart';

/// Fourteen hearts rising up the screen when a volume, or the whole
/// collection, is finished.
///
/// Every number is the design's: the hearts are spread across the width by
/// `6 + (i * 37) % 88` percent, sized `18 + (i * 7) % 22`, and released 90ms
/// apart. Each one climbs 520px over 2.4s while growing from .6 to 1.2,
/// fading in over the first 15% and back out across the rest.
class Hearts extends StatefulWidget {
  const Hearts({super.key, required this.edition, this.onDone});

  final Edition edition;

  /// Called when the celebration is over, so the shell can drop the overlay.
  final VoidCallback? onDone;

  /// How long a single heart flies.
  static const Duration flight = Duration(milliseconds: 2400);

  /// The gap between one heart leaving and the next.
  static const Duration stagger = Duration(milliseconds: 90);

  /// How long the whole celebration lasts.
  ///
  /// The design clears the hearts at 3s, which is before the last few have
  /// finished their 2.4s flight, so they wink out on the way up. Kept as it is
  /// drawn rather than extended to 3.57s.
  static const Duration total = Duration(milliseconds: 3000);

  static const int count = 14;

  @override
  State<Hearts> createState() => _HeartsState();
}

class _HeartsState extends State<Hearts> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Hearts.total,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(() => widget.onDone?.call());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) => AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final elapsed = Hearts.total * _controller.value;

            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                for (var i = 0; i < Hearts.count; i++)
                  _heart(i, elapsed, constraints.maxWidth),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _heart(int i, Duration elapsed, double width) {
    final started = elapsed - Hearts.stagger * i;
    final t = (started.inMicroseconds / Hearts.flight.inMicroseconds).clamp(
      0.0,
      1.0,
    );
    // `animation-fill-mode: both` holds the heart at its opening frame, which
    // is fully transparent, until its delay has passed.
    final progress = Curves.easeOut.transform(t);
    final opacity = t < 0.15 ? t / 0.15 : 1 - (t - 0.15) / 0.85;

    return Positioned(
      left: width * (6 + (i * 37) % 88) / 100,
      bottom: 120 + 520 * progress,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 0.6 + 0.6 * progress,
          child: Text(
            '♥',
            style: TextStyle(
              fontSize: (18 + (i * 7) % 22).toDouble(),
              color: widget.edition.accent,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
