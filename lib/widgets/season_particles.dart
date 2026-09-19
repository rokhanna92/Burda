import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/season.dart';

/// Where a particle comes in from.
enum _From { top, bottom, anywhere }

/// What a particle is drawn as.
enum _Shape {
  /// A plain round grain: snow and embers.
  dot,

  /// Round like a dot, but it twinkles: stars and dust.
  star,

  petal,
  leaf,
  sparkle,
}

/// What colour a particle takes.
enum _Tone {
  /// White, for snow and stars.
  white,

  /// The édition's accent, for petals, embers, dust and sun.
  accent,

  /// One of six autumn colours, for leaves.
  autumn,
}

/// The recipe for one kind of weather.
class _Recipe {
  const _Recipe({
    required this.count,
    required this.from,
    required this.speedY,
    required this.speedX,
    required this.size,
    required this.shape,
    required this.alpha,
    required this.tone,
  });

  final int count;
  final _From from;

  /// Pixels a second. Negative rises.
  final (double, double) speedY;
  final (double, double) speedX;
  final (double, double) size;
  final _Shape shape;
  final (double, double) alpha;
  final _Tone tone;

  /// Stars, dust and sun sparkles breathe; snow and embers do not.
  bool get twinkles => shape == _Shape.star || shape == _Shape.sparkle;
}

/// Every value here is the design's, from `season-window.js`.
const Map<Season, _Recipe> _recipes = {
  Season.snow: _Recipe(
    count: 26,
    from: _From.top,
    speedY: (8, 18),
    speedX: (-4, 4),
    size: (1.2, 3),
    shape: _Shape.dot,
    alpha: (0.55, 0.95),
    tone: _Tone.white,
  ),
  Season.leaves: _Recipe(
    count: 14,
    from: _From.top,
    speedY: (9, 20),
    speedX: (-10, 6),
    size: (2.5, 7),
    shape: _Shape.leaf,
    alpha: (0.7, 1),
    tone: _Tone.autumn,
  ),
  Season.petals: _Recipe(
    count: 16,
    from: _From.top,
    speedY: (6, 14),
    speedX: (-8, 8),
    size: (2.5, 4.5),
    shape: _Shape.petal,
    alpha: (0.6, 0.95),
    tone: _Tone.accent,
  ),
  Season.sun: _Recipe(
    count: 18,
    from: _From.anywhere,
    speedY: (-6, -2),
    speedX: (-3, 3),
    size: (0.8, 2),
    shape: _Shape.sparkle,
    alpha: (0.3, 0.9),
    tone: _Tone.accent,
  ),
  Season.stars: _Recipe(
    count: 34,
    from: _From.anywhere,
    speedY: (-1, 1),
    speedX: (-1, 1),
    size: (0.5, 1.6),
    shape: _Shape.star,
    alpha: (0.2, 1),
    tone: _Tone.white,
  ),
  Season.embers: _Recipe(
    count: 16,
    from: _From.bottom,
    speedY: (-16, -6),
    speedX: (-4, 4),
    size: (0.8, 2.2),
    shape: _Shape.dot,
    alpha: (0.4, 1),
    tone: _Tone.accent,
  ),
  Season.dust: _Recipe(
    count: 30,
    from: _From.anywhere,
    speedY: (-3, 3),
    speedX: (-3, 3),
    size: (0.5, 1.4),
    shape: _Shape.star,
    alpha: (0.2, 0.9),
    tone: _Tone.accent,
  ),
};

/// The six colours a falling leaf can be.
const List<Color> _autumn = [
  Color(0xFFB8541E),
  Color(0xFFD98A2B),
  Color(0xFF8A3A1B),
  Color(0xFFC9A227),
  Color(0xFFA0522D),
  Color(0xFF7B2D26),
];

class _Particle {
  double x = 0;
  double y = 0;
  double vx = 0;
  double vy = 0;
  double size = 0;
  double alpha = 0;
  double rotation = 0;
  double spin = 0;
  double phase = 0;

  /// Which of the five leaf shapes, for leaves only.
  int kind = 0;
  Color autumnColour = _autumn.first;
}

/// The drifting weather inside the nav bar's window.
///
/// Counts, speeds, sizes and shapes are the design's. It stops when the widget
/// is not being ticked, so it costs nothing while the app is in the background
/// or behind a route.
class SeasonParticles extends StatefulWidget {
  const SeasonParticles({
    super.key,
    required this.season,
    required this.accent,
  });

  final Season season;
  final Color accent;

  @override
  State<SeasonParticles> createState() => _SeasonParticlesState();
}

class _SeasonParticlesState extends State<SeasonParticles>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final math.Random _random = math.Random();
  List<_Particle> _particles = const [];
  Size _size = Size.zero;
  double _elapsed = 0;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void didUpdateWidget(SeasonParticles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.season != oldWidget.season) _particles = const [];
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  _Recipe get _recipe => _recipes[widget.season]!;

  double _between((double, double) range) =>
      range.$1 + _random.nextDouble() * (range.$2 - range.$1);

  void _place(_Particle p, {required bool fresh}) {
    final recipe = _recipe;
    p.size = _between(recipe.size);
    p.vx = _between(recipe.speedX);
    p.vy = _between(recipe.speedY);
    p.alpha = _between(recipe.alpha);
    p.rotation = _random.nextDouble() * math.pi * 2;
    p.spin = _between((-1.5, 1.5));
    p.phase = _random.nextDouble() * math.pi * 2;
    p.kind = _random.nextInt(5);
    p.autumnColour = _autumn[_random.nextInt(_autumn.length)];
    p.x = _random.nextDouble() * _size.width;
    // A fresh window starts with weather already in it, rather than waiting
    // for the first flake to fall in from the edge.
    if (fresh || recipe.from == _From.anywhere) {
      p.y = _random.nextDouble() * _size.height;
    } else if (recipe.from == _From.top) {
      p.y = -p.size * 2;
    } else {
      p.y = _size.height + p.size * 2;
    }
  }

  void _tick(Duration now) {
    if (_size.isEmpty) return;
    // Clamped so a long pause does not teleport everything at once.
    final dt = math.min(0.05, (now - _last).inMicroseconds / 1e6);
    _last = now;
    if (dt <= 0) return;
    _elapsed += dt;

    if (_particles.length != _recipe.count) {
      _particles = List.generate(_recipe.count, (_) {
        final p = _Particle();
        _place(p, fresh: true);
        return p;
      });
    }

    for (final p in _particles) {
      p.x += (p.vx + math.sin(_elapsed * 1.3 + p.phase) * 4) * dt;
      p.y += p.vy * dt;
      p.rotation += p.spin * dt;

      final gone =
          p.x < -8 ||
          p.x > _size.width + 8 ||
          p.y < -10 ||
          p.y > _size.height + 10;
      if (gone) _place(p, fresh: false);
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        return CustomPaint(
          painter: _ParticlePainter(
            particles: _particles,
            recipe: _recipe,
            accent: widget.accent,
            elapsed: _elapsed,
          ),
        );
      },
    );
  }
}

class _ParticlePainter extends CustomPainter {
  const _ParticlePainter({
    required this.particles,
    required this.recipe,
    required this.accent,
    required this.elapsed,
  });

  final List<_Particle> particles;
  final _Recipe recipe;
  final Color accent;
  final double elapsed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    for (final p in particles) {
      var alpha = p.alpha;
      // Stars, dust and sparkles breathe rather than sit still.
      if (recipe.twinkles) {
        alpha *=
            0.35 + 0.65 * (0.5 + 0.5 * math.sin(elapsed * 2.2 + p.phase * 3));
      }

      paint.color = switch (recipe.tone) {
        _Tone.white => Colors.white,
        _Tone.accent => accent,
        _Tone.autumn => p.autumnColour,
      }.withValues(alpha: alpha.clamp(0.0, 1.0));

      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);

      switch (recipe.shape) {
        case _Shape.dot:
        case _Shape.star:
          canvas.drawCircle(Offset.zero, p.size, paint);
        case _Shape.petal:
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size * 2,
              height: p.size * 1.1,
            ),
            paint,
          );
        case _Shape.sparkle:
          canvas.drawRect(
            Rect.fromLTWH(-p.size * 2, -p.size * 0.3, p.size * 4, p.size * 0.6),
            paint,
          );
          canvas.drawRect(
            Rect.fromLTWH(-p.size * 0.3, -p.size * 2, p.size * 0.6, p.size * 4),
            paint,
          );
        case _Shape.leaf:
          _paintLeaf(canvas, p, paint);
      }

      canvas.restore();
    }
  }

  /// Leaves tumble rather than simply spin, and are squashed as they turn.
  void _paintLeaf(Canvas canvas, _Particle p, Paint paint) {
    canvas.rotate(math.sin(elapsed * 1.7 + p.phase) * 0.35);
    canvas.scale(1, 0.75 + 0.25 * math.sin(elapsed * 2.1 + p.phase));

    final s = p.size;
    canvas.drawPath(_leafPath(p.kind, s), paint);

    // The midrib, a shade darker than the leaf itself.
    final rib = Paint()
      ..color = const Color(0xFF3A1A0A).withValues(alpha: paint.color.a * 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    canvas.drawLine(
      p.kind <= 1 ? Offset(-s, 0) : Offset(0, s),
      p.kind <= 1 ? Offset(s, 0) : Offset(0, -s * 0.7),
      rib,
    );
  }

  Path _leafPath(int kind, double s) {
    final path = Path();
    switch (kind) {
      case 0: // beech: a plain oval
        path.moveTo(-s, 0);
        path.quadraticBezierTo(0, -s * 0.8, s, 0);
        path.quadraticBezierTo(0, s * 0.8, -s, 0);
      case 1: // willow: a long lance
        path.moveTo(-s * 1.3, 0);
        path.quadraticBezierTo(0, -s * 0.45, s * 1.3, 0);
        path.quadraticBezierTo(0, s * 0.45, -s * 1.3, 0);
      case 2: // maple: five lobes
        for (var i = 0; i < 5; i++) {
          final angle = -math.pi / 2 + (i - 2) * 0.62;
          final reach = i == 2
              ? s * 1.15
              : (i == 1 || i == 3)
              ? s
              : s * 0.72;
          final px = math.cos(angle) * reach;
          final py = math.sin(angle) * reach + s * 0.25;
          if (i == 0) {
            path.moveTo(px, py);
          } else {
            final between = angle - 0.31;
            path.lineTo(
              math.cos(between) * s * 0.38,
              math.sin(between) * s * 0.38 + s * 0.25,
            );
            path.lineTo(px, py);
          }
        }
        path.lineTo(s * 0.35, s * 0.5);
        path.lineTo(0, s * 0.9);
        path.lineTo(-s * 0.35, s * 0.5);
        path.close();
      case 3: // oak: wavy lobes
        path.moveTo(0, -s);
        for (var i = 0; i < 4; i++) {
          final y = -s + (i + 0.5) * s * 0.5;
          path.quadraticBezierTo(s * 0.9, y - s * 0.1, s * 0.3, y + s * 0.25);
        }
        path.lineTo(0, s);
        for (var i = 3; i >= 0; i--) {
          final y = -s + (i + 0.5) * s * 0.5;
          path.quadraticBezierTo(
            -s * 0.9,
            y + s * 0.15,
            -s * 0.3,
            y - s * 0.25,
          );
        }
        path.close();
      default: // linden: a heart
        path.moveTo(0, s);
        path.quadraticBezierTo(-s * 1.1, 0, -s * 0.55, -s * 0.7);
        path.quadraticBezierTo(0, -s * 1.05, 0, -s * 0.5);
        path.quadraticBezierTo(0, -s * 1.05, s * 0.55, -s * 0.7);
        path.quadraticBezierTo(s * 1.1, 0, 0, s);
    }
    return path;
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => true;
}
