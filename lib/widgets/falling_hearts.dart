import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/edition.dart';
import '../theme/oklab.dart';

/// A brief shower of hearts down the screen when an issue is claimed.
///
/// The original app had this and it is the small pleasure of adding a
/// magazine, so it plays on every issue taken into the collection, not only on
/// the big milestones. They start above the top edge and fall past the bottom,
/// so none is ever seen appearing or vanishing.
///
/// Distinct from the hearts that rise on finishing a volume: those are a
/// celebration and go upwards.
class FallingHearts extends StatefulWidget {
  const FallingHearts({
    super.key,
    required this.edition,
    this.onDone,
    this.count = 18,
  });

  final Edition edition;

  /// Called once the last heart is off the bottom, so the overlay can go.
  final VoidCallback? onDone;

  final int count;

  /// Over how long the hearts set off, one after another.
  static const double spread = 0.6;

  /// The slowest a heart crosses the screen.
  static const double slowestFall = 1.9;

  /// How long the whole shower lasts.
  ///
  /// Long enough for the last heart released to reach the bottom: end it any
  /// sooner and hearts wink out in mid-air.
  static const Duration shower = Duration(milliseconds: 2500);

  @override
  State<FallingHearts> createState() => _FallingHeartsState();
}

/// One heart on its way down.
class _Heart {
  _Heart({
    required this.x,
    required this.size,
    required this.delay,
    required this.fall,
    required this.sway,
    required this.phase,
    required this.spin,
    required this.colour,
  });

  /// Across the screen, 0 to 1.
  final double x;
  final double size;

  /// Seconds before this one sets off.
  final double delay;

  /// Seconds it takes to cross the screen.
  final double fall;

  /// How far it wanders sideways on the way down.
  final double sway;
  final double phase;
  final double spin;
  final Color colour;
}

class _FallingHeartsState extends State<FallingHearts>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final math.Random _random = math.Random();
  late final List<_Heart> _hearts;
  double _elapsed = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _hearts = List.generate(widget.count, _make);
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  double _between(double a, double b) => a + _random.nextDouble() * (b - a);

  _Heart _make(int index) {
    final palette = _palette(widget.edition);
    // Spread evenly with a little jitter, so they arrive as a shower rather
    // than a wall, and the first sets off at once.
    final slot = index / widget.count * FallingHearts.spread;

    return _Heart(
      x: _random.nextDouble(),
      size: _between(14, 30),
      delay: (slot + _between(0, 0.05)).clamp(0.0, FallingHearts.spread),
      fall: _between(1.3, FallingHearts.slowestFall),
      sway: _between(10, 34),
      phase: _random.nextDouble() * math.pi * 2,
      spin: _between(-0.6, 0.6),
      colour: palette[_random.nextInt(palette.length)],
    );
  }

  void _tick(Duration now) {
    setState(() {
      _elapsed = now.inMicroseconds / 1e6;
    });
    if (_finished) return;
    if (_elapsed >= FallingHearts.shower.inMilliseconds / 1000) {
      _finished = true;
      _ticker.stop();
      widget.onDone?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          final width = constraints.maxWidth;

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              for (final heart in _hearts) ..._draw(heart, width, height),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _draw(_Heart heart, double width, double height) {
    final started = _elapsed - heart.delay;
    if (started < 0) return const [];

    final t = started / heart.fall;
    if (t > 1) return const [];

    // Starts a heart's height above the top and ends one below the bottom, so
    // it is never seen popping in or out.
    final top = -heart.size * 2 + (height + heart.size * 4) * t;
    final drift = math.sin(heart.phase + t * math.pi * 2) * heart.sway;

    return [
      Positioned(
        left: width * heart.x + drift - heart.size / 2,
        top: top,
        child: Transform.rotate(
          angle: heart.spin * t * math.pi,
          child: Text(
            '♥',
            style: TextStyle(
              fontSize: heart.size,
              height: 1,
              color: heart.colour,
            ),
          ),
        ),
      ),
    ];
  }
}

/// The colours a heart can be: the édition's accent and two neighbours of it.
///
/// Mixed in oklab towards the ink and the paper, so the lighter and darker
/// hearts stay the same hue as the accent rather than drifting grey. Every
/// édition gets a shower that belongs to it.
List<Color> _palette(Edition edition) => [
  edition.accent,
  edition.accent,
  mixOklab(edition.accent, edition.paper, 0.62),
  mixOklab(edition.accent, edition.ink, 0.72),
];
