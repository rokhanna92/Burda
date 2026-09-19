import 'dart:io';

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

  test('the design defines ten éditions', () {
    expect(spec, hasLength(10));
    expect(Edition.all, hasLength(10));
  });

  test('every édition matches the design hex for hex', () {
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

  test('seven éditions print by day and three by night', () {
    expect(Edition.day, hasLength(7));
    expect(Edition.night, hasLength(3));
    expect(Edition.night.map((e) => e.id), ['nuit', 'noir', 'bordeaux']);
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
}
