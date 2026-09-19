import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/edition.dart';
import '../theme/season.dart';
import 'season_particles.dart';

/// The porthole in the middle of the nav bar: a little sky that changes with
/// the édition.
///
/// A vertical sky gradient, a soft highlight drifting across it on a 9s
/// cycle, and a ground haze over the bottom third. Inset shadows at the top
/// and bottom give it the depth of a window rather than a sticker.
class SeasonWindow extends StatefulWidget {
  const SeasonWindow({
    super.key,
    required this.edition,
    this.size = 60,
    this.season,
  });

  final Edition edition;
  final double size;

  /// The weather to draw, when it is not the édition's own.
  ///
  /// The month page draws the month's season, so May carries petals whatever
  /// the app happens to be printed in. The sky and the ground stay the
  /// édition's, so no new colour enters the app.
  final Season? season;

  /// How long the highlight takes to drift from one side to the other.
  static const Duration sweep = Duration(seconds: 9);

  @override
  State<SeasonWindow> createState() => _SeasonWindowState();
}

class _SeasonWindowState extends State<SeasonWindow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _light = AnimationController(
    vsync: this,
    duration: SeasonWindow.sweep,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _light.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scene = SeasonScene.of(widget.edition);
    final season = widget.season ?? scene.season;
    // The highlight is drawn oversized and allowed to wander, so its soft
    // edge never shows inside the window.
    final overscan = widget.size * 0.4;
    final lightSize = widget.size + overscan * 2;

    return SizedBox.square(
      dimension: widget.size,
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              decoration: BoxDecoration(gradient: scene.sky),
            ),
            Positioned(
              left: -overscan,
              top: -overscan,
              width: lightSize,
              height: lightSize,
              child: AnimatedBuilder(
                animation: _light,
                builder: (context, child) {
                  final t = Curves.easeInOut.transform(_light.value);
                  return Transform.translate(
                    offset: Offset(
                      lightSize * (-0.06 + 0.16 * t),
                      lightSize * (-0.04 + 0.12 * t),
                    ),
                    child: Transform.rotate(
                      angle: t * 20 * math.pi / 180,
                      child: child,
                    ),
                  );
                },
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(-0.4, -0.4),
                      radius: 0.45,
                      colors: [Color(0x73FFFFFF), Color(0x00FFFFFF)],
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: 0.3,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  decoration: BoxDecoration(gradient: scene.ground),
                ),
              ),
            ),
            SeasonParticles(season: season, accent: widget.edition.accent),
            // Stands in for the CSS inset shadows, which Flutter has no direct
            // equivalent for: dark from the top edge, light from the bottom.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [Color(0x38000000), Color(0x00000000)],
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment(0, 0.4),
                  colors: [Color(0x40FFFFFF), Color(0x00FFFFFF)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
