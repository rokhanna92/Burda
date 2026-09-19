import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// How readable one colour is on another, by the WCAG measure.
///
/// Returns a ratio from 1, meaning the two are identical and nothing can be
/// read, to 21, black on white. The thresholds worth knowing: 4.5 is the floor
/// for ordinary text, 3 for large text, 7 for the stricter grade.
///
/// The app leans on this rather than on judgement by eye, because most of its
/// secondary text is the ink at partial strength, and how legible that lands
/// depends on the paper underneath it in a way that is easy to get wrong and
/// easy to measure.
double contrastRatio(Color a, Color b) {
  final first = _relativeLuminance(a);
  final second = _relativeLuminance(b);
  final lighter = math.max(first, second);
  final darker = math.min(first, second);
  return (lighter + 0.05) / (darker + 0.05);
}

/// [foreground] laid over [background] at [opacity], as one flat colour.
///
/// Graded ink is drawn with alpha, so its real contrast is against what shows
/// through, not against the ink's own value.
Color flatten(Color foreground, double opacity, Color background) => Color.from(
  alpha: 1,
  red: foreground.r * opacity + background.r * (1 - opacity),
  green: foreground.g * opacity + background.g * (1 - opacity),
  blue: foreground.b * opacity + background.b * (1 - opacity),
);

double _relativeLuminance(Color colour) {
  double channel(double value) => value <= 0.03928
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();

  return 0.2126 * channel(colour.r) +
      0.7152 * channel(colour.g) +
      0.0722 * channel(colour.b);
}
