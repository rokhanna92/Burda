import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Mixes two colours the way CSS `color-mix(in oklab, ...)` does.
///
/// The design reaches for this once, for the hatch a photo sits on. Mixing
/// straight in sRGB would take the tint through a muddy middle; oklab is
/// perceptually even, so the hatch stays the same hue as the block around it.
///
/// [weight] is how much of [a] survives, matching the CSS percentage: 0.7
/// reads as `color-mix(in oklab, a 70%, b)`.
Color mixOklab(Color a, Color b, double weight) {
  final left = _toOklab(a);
  final right = _toOklab(b);
  final t = 1 - weight;

  return _fromOklab(
    left.$1 + (right.$1 - left.$1) * t,
    left.$2 + (right.$2 - left.$2) * t,
    left.$3 + (right.$3 - left.$3) * t,
    a.a + (b.a - a.a) * t,
  );
}

double _toLinear(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _toGamma(double c) => c <= 0.0031308
    ? 12.92 * c
    : 1.055 * math.pow(c, 1 / 2.4).toDouble() - 0.055;

double _cbrt(double x) =>
    x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble();

(double, double, double) _toOklab(Color colour) {
  final r = _toLinear(colour.r);
  final g = _toLinear(colour.g);
  final b = _toLinear(colour.b);

  final l = _cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  final m = _cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  final s = _cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);

  return (
    0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
    1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
    0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
  );
}

Color _fromOklab(
  double lightness,
  double aChannel,
  double bChannel,
  double alpha,
) {
  final l = math
      .pow(lightness + 0.3963377774 * aChannel + 0.2158037573 * bChannel, 3)
      .toDouble();
  final m = math
      .pow(lightness - 0.1055613458 * aChannel - 0.0638541728 * bChannel, 3)
      .toDouble();
  final s = math
      .pow(lightness - 0.0894841775 * aChannel - 1.2914855480 * bChannel, 3)
      .toDouble();

  double channel(double value) => _toGamma(value).clamp(0.0, 1.0);

  return Color.from(
    alpha: alpha,
    red: channel(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
    green: channel(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
    blue: channel(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s),
  );
}
