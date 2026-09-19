import 'dart:io';

import 'package:burda/theme/contrast.dart';
import 'package:burda/theme/edition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pulls the `EDITIONS` array straight out of the design file, so the Dart
/// table is checked against the spec rather than against a second copy of it.
final _pattern = RegExp(
  r"\{ id: '(\w+)', no: '(\d+)', name: '([^']+)', "
  r"paper: '#(\w{6})', ink: '#(\w{6})', accent: '#(\w{6})', tint: '#(\w{6})', "
  r'dark: (true|false) \}',
);

Color _hex(String value) => Color(int.parse('FF$value', radix: 16));

void main() {
  final design = File('design/burda-style-design.html').readAsStringSync();
  final spec = _pattern.allMatches(design).toList();

  test('the design defines ten éditions, and the app adds eight', () {
    expect(spec, hasLength(10));
    expect(Edition.all, hasLength(18));
    // The design's ten come first and unaltered; the clear set follows.
    expect(Edition.all.take(10).map((e) => e.id), spec.map((m) => m.group(1)));
  });

  test('every édition of the design matches it hex for hex', () {
    for (var i = 0; i < spec.length; i++) {
      final match = spec[i];
      final edition = Edition.all[i];
      final where = 'édition ${match.group(1)}';

      expect(edition.id, match.group(1), reason: where);
      expect(edition.no, match.group(2), reason: where);
      expect(edition.name, match.group(3), reason: where);
      expect(edition.paper, _hex(match.group(4)!), reason: '$where paper');
      expect(edition.ink, _hex(match.group(5)!), reason: '$where ink');
      expect(edition.accent, _hex(match.group(6)!), reason: '$where accent');
      expect(edition.tint, _hex(match.group(7)!), reason: '$where tint');
      expect(edition.dark, match.group(8) == 'true', reason: '$where dark');
    }
  });

  test('every édition prints by day or by night', () {
    expect(Edition.day.length + Edition.night.length, Edition.all.length);
    expect(Edition.day, hasLength(11));
    expect(Edition.night, hasLength(7));
  });

  test('the numbers run from 1 without a gap or a repeat', () {
    expect(Edition.all.map((e) => e.no).toList(), [
      for (var n = 1; n <= Edition.all.length; n++) '$n',
    ]);
  });

  test('no two éditions share an id or a name', () {
    expect(Edition.all.map((e) => e.id).toSet(), hasLength(Edition.all.length));
    expect(
      Edition.all.map((e) => e.name).toSet(),
      hasLength(Edition.all.length),
    );
  });

  group('byId', () {
    test('finds an édition', () {
      expect(Edition.byId('hiver'), Edition.hiver);
    });

    test('falls back to Rosé, which is the design default', () {
      // An install carrying one of the old palette names lands here.
      expect(Edition.byId('mellon'), Edition.rose);
      expect(Edition.byId(null), Edition.rose);
    });

    test("keeps 'maroon' pointing at the new édition, not the old palette", () {
      // The only id the two schemes share, and the colours are unrelated.
      expect(Edition.byId('maroon'), Edition.maroon);
      expect(Edition.maroon.paper, const Color(0xFFF6EEEA));
    });
  });

  group('inkAt', () {
    test('grades ink by the design percentage', () {
      expect(Edition.rose.inkAt(60).a, closeTo(0.6, 0.01));
      expect(Edition.rose.inkAt(60).r, Edition.rose.ink.r);
    });

    test('muted is ink at 55%', () {
      expect(Edition.rose.muted, Edition.rose.inkAt(55));
    });
  });

  group('readability', () {
    /// The floor for ordinary text, by the WCAG measure.
    const floor = 4.5;

    /// The eight added because the originals were reported as hard to read.
    final clear = Edition.all.skip(10).toList();

    test('body text is strong on every édition', () {
      for (final edition in Edition.all) {
        expect(
          contrastRatio(edition.ink, edition.paper),
          greaterThan(12),
          reason: edition.id,
        );
      }
    });

    test('the édition picks the better of paper and white for the accent', () {
      const white = Color(0xFFFFFFFF);
      for (final edition in Edition.all) {
        final chosen = contrastRatio(edition.onAccent, edition.accent);
        expect(
          chosen,
          greaterThanOrEqualTo(contrastRatio(white, edition.accent)),
          reason: edition.id,
        );
        expect(
          chosen,
          greaterThanOrEqualTo(contrastRatio(edition.paper, edition.accent)),
          reason: edition.id,
        );
      }
    });

    test('something close to legible sits on every accent', () {
      // Été is the one that grazes it, at 4.49 against a floor of 4.5. Its
      // colours are the design's and are left alone; the clear set below is
      // the answer to it. Before onAccent, three night éditions sat at 2.3 to
      // 3.8 here.
      for (final edition in Edition.all) {
        expect(
          contrastRatio(edition.onAccent, edition.accent),
          greaterThan(4.4),
          reason: edition.id,
        );
      }
    });

    test('the clear set clears the floor on its accent outright', () {
      for (final edition in clear) {
        expect(
          contrastRatio(edition.onAccent, edition.accent),
          greaterThanOrEqualTo(floor),
          reason: edition.id,
        );
      }
    });

    test('the clear set carries its secondary text', () {
      // Most of the app's quieter text is ink at 55%, and on the original day
      // éditions that lands at 3.4 to 4.2. These were drawn to clear the
      // floor with it.
      for (final edition in clear) {
        final secondary = flatten(edition.ink, 0.55, edition.paper);
        expect(
          contrastRatio(secondary, edition.paper),
          greaterThanOrEqualTo(floor),
          reason: '${edition.id} secondary text',
        );
      }
    });

    test('the clear set carries its accent text', () {
      for (final edition in clear) {
        expect(
          contrastRatio(edition.accent, edition.paper),
          greaterThanOrEqualTo(floor),
          reason: '${edition.id} accent text',
        );
      }
    });

    test('the clear set is split evenly between day and night', () {
      expect(clear.where((e) => !e.dark), hasLength(4));
      expect(clear.where((e) => e.dark), hasLength(4));
    });
  });
}
