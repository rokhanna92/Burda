import 'package:flutter/material.dart';

import 'contrast.dart';
import 'oklab.dart';

/// One of the eighteen "Éditions" the app can be printed in.
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

  /// The édition number the profile cards print, `"1"` through `"18"`.
  final String no;

  /// Display name, e.g. `"Rosé"`.
  final String name;

  final Color paper;
  final Color ink;
  final Color accent;
  final Color tint;

  /// True for a night édition, which prints light ink on dark paper.
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

  /// What to print on top of the [accent].
  ///
  /// Whichever of paper or white can actually be read there, rather than white
  /// always. On a night édition the accent is bright, and white on it was
  /// landing at a contrast of 2.3 where 4.5 is the floor: the condition marks
  /// and the remove button were close to unreadable.
  Color get onAccent {
    const white = Color(0xFFFFFFFF);
    return contrastRatio(white, accent) >= contrastRatio(paper, accent)
        ? white
        : paper;
  }

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
    fuchsia,
    rubis,
    cobalt,
    emeraude,
    orchidee,
    carmin,
    indigo,
    sapin,
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

  // The clear set. Drawn to a contrast budget rather than by eye: the ink
  // reaches 20 against the paper, which is what it takes for the secondary
  // text, printed at 55% ink, to clear the 4.5 readability floor. On the
  // seven original day éditions it lands at 3.4 to 4.2, which is the "hard to
  // read" they were reported as.

  static const Edition fuchsia = Edition(
    id: 'fuchsia',
    no: '11',
    name: 'Fuchsia',
    paper: Color(0xFFFFFCFD),
    ink: Color(0xFF0C0206),
    accent: Color(0xFFB8005A),
    tint: Color(0xFFFFD4E6),
    dark: false,
  );

  static const Edition rubis = Edition(
    id: 'rubis',
    no: '12',
    name: 'Rubis',
    paper: Color(0xFFFFFCFB),
    ink: Color(0xFF0D0305),
    accent: Color(0xFFA80018),
    tint: Color(0xFFFFD6D2),
    dark: false,
  );

  static const Edition cobalt = Edition(
    id: 'cobalt',
    no: '13',
    name: 'Cobalt',
    paper: Color(0xFFFBFDFF),
    ink: Color(0xFF02050E),
    accent: Color(0xFF003C8F),
    tint: Color(0xFFCFE0FA),
    dark: false,
  );

  static const Edition emeraude = Edition(
    id: 'emeraude',
    no: '14',
    name: 'Émeraude',
    paper: Color(0xFFFBFFFC),
    ink: Color(0xFF010805),
    accent: Color(0xFF005C36),
    tint: Color(0xFFC6E8D4),
    dark: false,
  );

  static const Edition orchidee = Edition(
    id: 'orchidee',
    no: '15',
    name: 'Orchidée',
    paper: Color(0xFF0B040A),
    ink: Color(0xFFFFF6FA),
    accent: Color(0xFFFF8FC2),
    tint: Color(0xFF1F1122),
    dark: true,
  );

  static const Edition carmin = Edition(
    id: 'carmin',
    no: '16',
    name: 'Carmin',
    paper: Color(0xFF0E0406),
    ink: Color(0xFFFFF5F4),
    accent: Color(0xFFFF7B84),
    tint: Color(0xFF271014),
    dark: true,
  );

  static const Edition indigo = Edition(
    id: 'indigo',
    no: '17',
    name: 'Indigo',
    paper: Color(0xFF040711),
    ink: Color(0xFFF4F7FF),
    accent: Color(0xFF9DBEFF),
    tint: Color(0xFF101829),
    dark: true,
  );

  static const Edition sapin = Edition(
    id: 'sapin',
    no: '18',
    name: 'Sapin',
    paper: Color(0xFF020C07),
    ink: Color(0xFFF2FDF6),
    accent: Color(0xFF6FE9AC),
    tint: Color(0xFF0B2115),
    dark: true,
  );
}
