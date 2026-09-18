import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One sewing icon circling the logo.
class _Orbiter {
  const _Orbiter({
    required this.asset,
    required this.size,
    required this.center,
    required this.radius,
    required this.speed,
    required this.phase,
  });

  final String asset;
  final double size;

  /// Where the orbit is centred, as a fraction of the title box.
  final Offset center;

  /// Orbit half width and half height, also as fractions.
  final Offset radius;

  /// Turns per full cycle of the shared controller.
  final double speed;
  final double phase;
}

/// The "Burda Style" script logo with its rose gradient and the six sewing
/// icons that drift around it, the way the original's title does.
class TitleText extends StatefulWidget {
  const TitleText({
    super.key,
    this.text = 'Burda Style',
    this.fontSize = 58,
    this.height = 150,
  });

  final String text;
  final double fontSize;
  final double height;

  @override
  State<TitleText> createState() => _TitleTextState();
}

class _TitleTextState extends State<TitleText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(seconds: 30),
    vsync: this,
  )..repeat();

  static const Gradient _rose = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEFBDBD), Color(0xFFD78080), Color(0xFFC06868)],
    stops: [0, 0.55, 1],
  );

  static const List<_Orbiter> _orbiters = [
    _Orbiter(
      asset: 'assets/icon/flame.png',
      size: 44,
      center: Offset(0.20, 0.42),
      radius: Offset(0.05, 0.13),
      speed: 1,
      phase: 0,
    ),
    _Orbiter(
      asset: 'assets/icon/thread.png',
      size: 46,
      center: Offset(0.37, 0.12),
      radius: Offset(0.05, 0.10),
      speed: 0.8,
      phase: 1.1,
    ),
    _Orbiter(
      asset: 'assets/icon/sewing-machine.png',
      size: 48,
      center: Offset(0.61, 0.10),
      radius: Offset(0.06, 0.09),
      speed: 0.7,
      phase: 2.2,
    ),
    _Orbiter(
      asset: 'assets/icon/dress.png',
      size: 38,
      center: Offset(0.49, 0.30),
      radius: Offset(0.04, 0.12),
      speed: 1.2,
      phase: 3.3,
    ),
    _Orbiter(
      asset: 'assets/icon/yarn.png',
      size: 36,
      center: Offset(0.54, 0.74),
      radius: Offset(0.05, 0.10),
      speed: 0.9,
      phase: 4.4,
    ),
    _Orbiter(
      asset: 'assets/icon/needle.png',
      size: 34,
      center: Offset(0.80, 0.60),
      radius: Offset(0.05, 0.12),
      speed: 1.1,
      phase: 5.5,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
              Center(child: _logo()),
              for (final orbiter in _orbiters) _orbit(orbiter, area),
            ],
          );
        },
      ),
    );
  }

  Widget _logo() {
    return ShaderMask(
      shaderCallback: (bounds) => _rose.createShader(bounds),
      blendMode: BlendMode.srcIn,
      // The script face inks well outside its text box, which ShaderMask would
      // otherwise cut off, hence the padding.
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            widget.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.script,
              fontSize: widget.fontSize,
              height: 1.1,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _orbit(_Orbiter orbiter, Size area) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value * 2 * pi * orbiter.speed + orbiter.phase;
        return Positioned(
          left:
              area.width * (orbiter.center.dx + orbiter.radius.dx * cos(t)) -
              orbiter.size / 2,
          top:
              area.height * (orbiter.center.dy + orbiter.radius.dy * sin(t)) -
              orbiter.size / 2,
          child: child!,
        );
      },
      child: Image.asset(
        orbiter.asset,
        width: orbiter.size,
        height: orbiter.size,
      ),
    );
  }
}
