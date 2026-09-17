import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The "Burda Style" script logo with its rose vertical gradient.
class TitleText extends StatelessWidget {
  const TitleText({super.key, this.text = 'Burda Style', this.fontSize = 58});

  final String text;
  final double fontSize;

  static const Gradient _rose = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEFBDBD), Color(0xFFD78080), Color(0xFFC06868)],
    stops: [0, 0.55, 1],
  );

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => _rose.createShader(bounds),
      blendMode: BlendMode.srcIn,
      // The script face is very wide and its swashes ink well outside the text
      // box, which ShaderMask would otherwise cut off, hence the padding. The
      // FittedBox keeps it from clipping on narrow screens.
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.script,
              fontSize: fontSize,
              height: 1.1,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
