import 'dart:math';

import 'package:flutter/material.dart';

/// One drifting icon: where it sits, how big it is, and its motion phase.
class _Drifter {
  const _Drifter(this.asset, this.x, this.y, this.size, this.phase);

  final String asset;

  /// Fractions of the available width and height.
  final double x;
  final double y;
  final double size;
  final double phase;
}

/// The drifting sewing icons behind the home screen.
///
/// These sit behind [child] so they never cover text, which they did in the
/// original. The four tappable icons live in [DriftingIconCluster] instead, as
/// part of the page content.
class FloatingBackground extends StatefulWidget {
  const FloatingBackground({super.key, required this.child});

  final Widget child;

  @override
  State<FloatingBackground> createState() => _FloatingBackgroundState();
}

class _FloatingBackgroundState extends State<FloatingBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(seconds: 24),
    vsync: this,
  )..repeat();

  static const List<_Drifter> _decorative = [
    _Drifter('assets/icon/thread.png', 0.36, 0.005, 46, 0.0),
    _Drifter('assets/icon/sewing-machine.png', 0.60, 0.010, 46, 0.6),
    _Drifter('assets/icon/dress.png', 0.49, 0.055, 38, 1.2),
    _Drifter('assets/icon/yarn.png', 0.55, 0.135, 34, 1.8),
    _Drifter('assets/icon/flame.png', 0.20, 0.060, 40, 2.4),
    _Drifter('assets/icon/knitting.png', 0.80, 0.300, 40, 3.0),
    _Drifter('assets/icon/button.png', 0.12, 0.430, 34, 3.6),
    _Drifter('assets/icon/tape.png', 0.86, 0.560, 38, 4.2),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Slow figure-of-eight drift, unique per icon.
  Offset _drift(double phase) {
    final t = _controller.value * 2 * pi;
    return Offset(sin(t + phase) * 9, cos((t + phase) * 0.7) * 13);
  }

  Widget _floating(_Drifter drifter, Size area, {Widget? child}) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final offset = _drift(drifter.phase);
        return Positioned(
          left: area.width * drifter.x + offset.dx,
          top: area.height * drifter.y + offset.dy,
          child:
              child ??
              Image.asset(
                drifter.asset,
                width: drifter.size,
                height: drifter.size,
              ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final area = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          children: [
            IgnorePointer(
              child: Stack(
                children: [
                  for (final drifter in _decorative) _floating(drifter, area),
                ],
              ),
            ),
            widget.child,
          ],
        );
      },
    );
  }
}

/// The four icons that do something when tapped: the tour, the "coming soon"
/// joke, the coffee counter and search.
///
/// This is page content, placed below the tiles, so the icons drift in empty
/// space on any screen size instead of over the text.
class DriftingIconCluster extends StatefulWidget {
  const DriftingIconCluster({
    super.key,
    this.onSearchTap,
    this.onTourTap,
    this.onCoffeeTap,
    this.onComingSoonTap,
    this.height = 128,
  });

  final VoidCallback? onSearchTap;
  final VoidCallback? onTourTap;
  final VoidCallback? onCoffeeTap;
  final VoidCallback? onComingSoonTap;
  final double height;

  @override
  State<DriftingIconCluster> createState() => _DriftingIconClusterState();
}

class _DriftingIconClusterState extends State<DriftingIconCluster>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(seconds: 18),
    vsync: this,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _icon(_Drifter drifter, Size area, VoidCallback? onTap) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * 2 * pi;
        return Positioned(
          left: area.width * drifter.x + sin(t + drifter.phase) * 7,
          top: area.height * drifter.y + cos((t + drifter.phase) * 0.8) * 8,
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Image.asset(
                drifter.asset,
                width: drifter.size,
                height: drifter.size,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final area = Size(constraints.maxWidth, widget.height);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              _icon(
                const _Drifter('assets/icon/question.png', 0.63, 0.06, 38, 0.3),
                area,
                widget.onTourTap,
              ),
              _icon(
                const _Drifter(
                  'assets/icon/tracking-app.png',
                  0.44,
                  0.34,
                  38,
                  1.1,
                ),
                area,
                widget.onComingSoonTap,
              ),
              _icon(
                const _Drifter(
                  'assets/icon/coffee-cup.png',
                  0.22,
                  0.12,
                  38,
                  2.0,
                ),
                area,
                widget.onCoffeeTap,
              ),
              _icon(
                const _Drifter(
                  'assets/icon/searching.png',
                  0.74,
                  0.34,
                  44,
                  2.9,
                ),
                area,
                widget.onSearchTap,
              ),
            ],
          );
        },
      ),
    );
  }
}
