import 'package:burda/theme/edition.dart';
import 'package:burda/theme/oklab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a full weight keeps the first colour', () {
    expect(
      mixOklab(const Color(0xFFF1DDE0), const Color(0xFF2A1D1E), 1).r,
      closeTo(const Color(0xFFF1DDE0).r, 0.002),
    );
  });

  test('no weight gives the second colour', () {
    final mixed = mixOklab(const Color(0xFFF1DDE0), const Color(0xFF2A1D1E), 0);
    expect(mixed.r, closeTo(const Color(0xFF2A1D1E).r, 0.002));
    expect(mixed.g, closeTo(const Color(0xFF2A1D1E).g, 0.002));
  });

  test('mixing keeps the result between the two', () {
    final tint = Edition.rose.tint;
    final ink = Edition.rose.ink;
    final mixed = mixOklab(tint, ink, 0.7);

    expect(mixed.r, lessThan(tint.r));
    expect(mixed.r, greaterThan(ink.r));
  });

  test('is a perceptual mix, not a flat sRGB blend', () {
    final tint = Edition.rose.tint;
    final ink = Edition.rose.ink;

    final oklab = mixOklab(tint, ink, 0.7);
    final srgb = Color.lerp(tint, ink, 0.3)!;

    // Same two colours, same ratio, a different answer: the mix really does
    // go through oklab rather than straight down the sRGB line.
    expect((oklab.r - srgb.r).abs(), greaterThan(0.01));
  });

  test('mixing a colour with itself changes nothing', () {
    const colour = Color(0xFF6B4E9B);
    for (final weight in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      final mixed = mixOklab(colour, colour, weight);
      expect(mixed.r, closeTo(colour.r, 0.002), reason: '$weight');
      expect(mixed.g, closeTo(colour.g, 0.002), reason: '$weight');
      expect(mixed.b, closeTo(colour.b, 0.002), reason: '$weight');
    }
  });

  test('every édition can draw its hatch', () {
    for (final edition in Edition.all) {
      expect(edition.hatch.a, 1, reason: edition.id);
    }
  });
}
