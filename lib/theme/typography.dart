import 'package:flutter/material.dart';

/// Font families bundled for the redesign.
abstract final class AppFonts {
  /// Cormorant Garamond, the face the whole redesign is set in.
  ///
  /// Declared as a variable font, so weight travels in [TextStyle.fontVariations]
  /// rather than [TextStyle.fontWeight]. Use [AppType.serif] instead of naming
  /// this directly.
  static const String serif = 'CormorantGaramond';

  /// The script face, used for the "Burda Style" logo and nothing else.
  static const String script = 'FleurDeLeah';
}

/// Text styles for the redesign.
///
/// The design is written as CSS against a 402px-wide frame: sizes are in
/// pixels and tracking is in `em`, a fraction of the size. Flutter wants
/// tracking in logical pixels, so [serif] takes the design's `em` value and
/// does the multiplication, which keeps call sites readable next to the
/// design file.
abstract final class AppType {
  /// A style in Cormorant Garamond.
  ///
  /// [weight] is a variable-font axis value (the face spans 300 to 700), not a
  /// [FontWeight]. [trackingEm] is the design's `letter-spacing` in `em`.
  /// [smallCaps] turns on the face's own `smcp` table rather than faking small
  /// caps with scaled capitals; [tabular] turns on `tnum`, which the design
  /// asks for wherever numbers have to line up in a column.
  static TextStyle serif({
    required double size,
    double weight = 400,
    double trackingEm = 0,
    bool italic = false,
    bool smallCaps = false,
    bool tabular = false,
    double? height,
    Color? color,
  }) => TextStyle(
    fontFamily: AppFonts.serif,
    fontSize: size,
    fontVariations: [FontVariation('wght', weight)],
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    letterSpacing: trackingEm == 0 ? null : size * trackingEm,
    height: height,
    color: color,
    fontFeatures: [
      if (smallCaps) const FontFeature.enable('smcp'),
      if (tabular) const FontFeature.tabularFigures(),
    ],
  );

  /// A small-caps label, the design's workhorse for eyebrows, tabs, section
  /// headings and button text.
  static TextStyle smallCaps({
    required double size,
    required double trackingEm,
    double weight = 400,
    Color? color,
    double? height,
  }) => serif(
    size: size,
    weight: weight,
    trackingEm: trackingEm,
    smallCaps: true,
    color: color,
    height: height,
  );

  /// The "Burda Style" logo.
  static TextStyle logo({required double size, Color? color, double? height}) =>
      TextStyle(
        fontFamily: AppFonts.script,
        fontSize: size,
        height: height,
        color: color,
      );
}
