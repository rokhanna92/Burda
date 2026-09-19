import 'package:flutter/material.dart';

import 'oklab.dart';

/// One of the ten "Éditions" the app can be printed in.
///
/// The redesign drops the old palette roles (deep/dark/light) for the four a
/// printed page has: [paper] behind everything, [ink] for text and rules,
/// [accent] for the one colour that carries emphasis, and [tint] for the blocks
/// a cover sits in before its image loads.
///
/// Values are the design's, hex for hex.
@immutable
class Edition {
  const Edition({
    required this.id,
    required this.no,
    required this.name,
    required this.paper,
    required this.ink,
    required this.accent,
    required this.tint,
    required this.dark,
  });

  /// Stored in preferences under `theme`.
  final String id;

  /// The édition number the profile cards print, `"1"` through `"10"`.
  final String no;

  /// Display name, e.g. `"Rosé"`.
  final String name;

  final Color paper;
  final Color ink;
  final Color accent;
  final Color tint;

  /// True for the three night éditions, which print light ink on dark paper.
  ///
  /// Drives the status bar icons, not any colour choice: every colour already
  /// comes from the four roles above.
  final bool dark;

  /// [ink] at [percent] opacity.
  ///
  /// The design writes this as `color-mix(in oklab, var(--ink) N%, transparent)`,
  /// which is just ink at N% alpha, and reaches for it constantly to grade text
  /// and hairlines away from full strength. Call sites pass the design's own
  /// number, so `inkAt(60)` sits next to `60%,transparent` in the spec.
  Color inkAt(double percent) => ink.withValues(alpha: percent / 100);

  /// [ink] at 55%, the design's secondary text colour.
  Color get muted => inkAt(55);

  /// The darker thread in the diagonal hatch a photo sits on.
  ///
  /// The design's one true colour mix: `color-mix(in oklab, tint 70%, ink)`.
  Color get hatch => mixOklab(tint, ink, 0.7);

  /// The profile screen prints the day éditions in one row and the night ones
  /// in another.
  static List<Edition> get day =>
      all.where((edition) => !edition.dark).toList(growable: false);

  static List<Edition> get night =>
      all.where((edition) => edition.dark).toList(growable: false);

  static Edition byId(String? id) =>
      all.firstWhere((edition) => edition.id == id, orElse: () => rose);

  static const List<Edition> all = [
    rose,
    printemps,
    ete,
    automne,
    hiver,
    maroon,
    lavande,
    nuit,
    noir,
    bordeaux,
  ];

  static const Edition rose = Edition(
    id: 'rose',
    no: '1',
    name: 'Rosé',
    paper: Color(0xFFFAF3F0),
    ink: Color(0xFF2A1D1E),
    accent: Color(0xFFC2445F),
    tint: Color(0xFFF1DDE0),
    dark: false,
  );

  static const Edition printemps = Edition(
    id: 'printemps',
    no: '2',
    name: 'Printemps',
    paper: Color(0xFFF6F4EC),
    ink: Color(0xFF1F2A22),
    accent: Color(0xFF3F7A4C),
    tint: Color(0xFFDEE8DA),
    dark: false,
  );

  static const Edition ete = Edition(
    id: 'ete',
    no: '3',
    name: 'Été',
    paper: Color(0xFFFBF5E6),
    ink: Color(0xFF2B2417),
    accent: Color(0xFFC4552A),
    tint: Color(0xFFF6DFCB),
    dark: false,
  );

  static const Edition automne = Edition(
    id: 'automne',
    no: '4',
    name: 'Automne',
    paper: Color(0xFFF4ECE2),
    ink: Color(0xFF2C1F17),
    accent: Color(0xFF9A4A1F),
    tint: Color(0xFFE9D5C3),
    dark: false,
  );

  static const Edition hiver = Edition(
    id: 'hiver',
    no: '5',
    name: 'Hiver',
    paper: Color(0xFFF3F5F8),
    ink: Color(0xFF16202E),
    accent: Color(0xFF2F4C7A),
    tint: Color(0xFFD8E0ED),
    dark: false,
  );

  static const Edition maroon = Edition(
    id: 'maroon',
    no: '6',
    name: 'Maroon',
    paper: Color(0xFFF6EEEA),
    ink: Color(0xFF3A1218),
    accent: Color(0xFF7A1F2B),
    tint: Color(0xFFEAD5D2),
    dark: false,
  );

  static const Edition lavande = Edition(
    id: 'lavande',
    no: '7',
    name: 'Lavande',
    paper: Color(0xFFF5F2F8),
    ink: Color(0xFF251E36),
    accent: Color(0xFF6B4E9B),
    tint: Color(0xFFE4DDEE),
    dark: false,
  );

  static const Edition nuit = Edition(
    id: 'nuit',
    no: '8',
    name: 'Nuit',
    paper: Color(0xFF121417),
    ink: Color(0xFFECE9E4),
    accent: Color(0xFFD98A9C),
    tint: Color(0xFF1F2329),
    dark: true,
  );

  static const Edition noir = Edition(
    id: 'noir',
    no: '9',
    name: 'Noir',
    paper: Color(0xFF171512),
    ink: Color(0xFFEFE7D9),
    accent: Color(0xFFC9A45C),
    tint: Color(0xFF2A2621),
    dark: true,
  );

  static const Edition bordeaux = Edition(
    id: 'bordeaux',
    no: '10',
    name: 'Bordeaux',
    paper: Color(0xFF1B0F13),
    ink: Color(0xFFF3E4E4),
    accent: Color(0xFFD9556F),
    tint: Color(0xFF2C181E),
    dark: true,
  );
}
