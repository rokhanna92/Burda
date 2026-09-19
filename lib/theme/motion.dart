import 'package:flutter/animation.dart';

/// The easing and timings the design reuses across screens.
///
/// Values are the design's own: [standard] is its `cubic-bezier(.2,.7,.2,1)`,
/// which carries page entrances, bar fills and presses, and [sheet] is the
/// slightly longer-tailed `cubic-bezier(.2,.8,.2,1)` reserved for a sheet
/// rising from the bottom.
abstract final class AppMotion {
  static const Curve standard = Cubic(0.2, 0.7, 0.2, 1);
  static const Curve sheet = Cubic(0.2, 0.8, 0.2, 1);

  /// `pageIn`, a screen fading up as a tab is selected.
  static const Duration pageIn = Duration(milliseconds: 400);

  /// `pageInX`, a pushed screen sliding in from the right.
  static const Duration pageInX = Duration(milliseconds: 380);

  /// `sheetUp`.
  static const Duration sheetUp = Duration(milliseconds: 420);

  /// `toastIn`.
  static const Duration toastIn = Duration(milliseconds: 300);

  /// How long a toast stays up before it goes.
  static const Duration toastLinger = Duration(milliseconds: 2200);

  /// `coverIn`, a cover settling into a grid.
  static const Duration coverIn = Duration(milliseconds: 400);

  /// The stagger between one cover and the next.
  static const Duration coverStagger = Duration(milliseconds: 40);
}
