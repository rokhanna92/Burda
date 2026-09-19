import 'package:burda/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppType.serif', () {
    test('carries weight on the variable axis, not fontWeight', () {
      final style = AppType.serif(size: 46, weight: 500);

      expect(style.fontFamily, AppFonts.serif);
      expect(style.fontVariations, [const FontVariation('wght', 500)]);
      expect(style.fontWeight, isNull);
    });

    test('converts the design tracking from em to logical pixels', () {
      // The design writes `font-size:13px; letter-spacing:.24em`.
      expect(AppType.serif(size: 13, trackingEm: 0.24).letterSpacing, 13 * 0.24);
    });

    test('leaves tracking unset when the design gives none', () {
      expect(AppType.serif(size: 17).letterSpacing, isNull);
    });

    test('asks for the face\'s own small caps rather than faking them', () {
      final style = AppType.serif(size: 13, smallCaps: true);

      expect(style.fontFeatures, contains(const FontFeature.enable('smcp')));
    });

    test('turns on tabular figures only when asked', () {
      expect(
        AppType.serif(size: 26, tabular: true).fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      expect(AppType.serif(size: 26).fontFeatures, isEmpty);
    });

    test('selects the italic cut through fontStyle', () {
      expect(AppType.serif(size: 19, italic: true).fontStyle, FontStyle.italic);
      expect(AppType.serif(size: 19).fontStyle, FontStyle.normal);
    });
  });

  test('AppType.smallCaps is a small-caps serif style', () {
    final style = AppType.smallCaps(size: 15, trackingEm: 0.16);

    expect(style.fontFamily, AppFonts.serif);
    expect(style.fontFeatures, contains(const FontFeature.enable('smcp')));
    expect(style.letterSpacing, 15 * 0.16);
  });

  test('AppType.logo uses the script face', () {
    expect(AppType.logo(size: 66).fontFamily, AppFonts.script);
  });
}
