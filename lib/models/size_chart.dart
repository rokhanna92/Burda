import 'package:flutter/foundation.dart';

/// One line of the table Burda prints on the inside back cover.
@immutable
class SizeRow {
  const SizeRow({
    required this.size,
    required this.bust,
    required this.waist,
    required this.hip,
    required this.backWaist,
    required this.uk,
    required this.us,
  });

  /// The German size the magazine prints, 34 to 52.
  final int size;

  /// Body measurements in centimetres, not finished garment measurements.
  final double bust;
  final double waist;
  final double hip;

  /// Nape of the neck to the waist.
  final double backWaist;

  final int uk;
  final int us;
}

/// How much room a garment is cut with beyond the body, at the bust.
@immutable
class EaseBand {
  const EaseBand(this.label, this.range);

  final String label;
  final String range;
}

/// Which run of the chart a height falls in.
///
/// The body measurements are the same in all three. A run changes the length a
/// pattern is drafted to and the number the magazine prints on it: Burda halves
/// the size for a short run and doubles it for a tall one, so a 40 is a 20 in
/// Kurzgrößen and an 80 in Langgrößen.
enum SizeRun {
  petite('Petite', 'Kurzgrößen, under 160 cm'),
  standard('Standard', 'Normalgrößen, 160 to 172 cm'),
  tall('Tall', 'Langgrößen, over 172 cm');

  const SizeRun(this.label, this.note);

  final String label;

  /// What the magazine calls it, and the heights it is drafted for.
  final String note;

  String numberFor(int size) => switch (this) {
    SizeRun.petite => '${size ~/ 2}',
    SizeRun.standard => '$size',
    SizeRun.tall => '${size * 2}',
  };

  /// An unknown height is [standard]: the chart is drafted to it, so it is what
  /// she gets until she says otherwise.
  static SizeRun forHeight(double? cm) => cm == null
      ? SizeRun.standard
      : switch (cm) {
          < 160 => SizeRun.petite,
          > 172 => SizeRun.tall,
          _ => SizeRun.standard,
        };
}

/// Burda's measurement table, and the sizes it gives.
///
/// Check these against the issue you are cutting from before trusting them.
/// They are the table as the magazine has printed it for years, but a wrong row
/// here is worse than no chart at all, because it is a row she will cut to.
abstract final class SizeChart {
  static const List<SizeRow> rows = [
    SizeRow(
      size: 34,
      bust: 80,
      waist: 64,
      hip: 88,
      backWaist: 40.0,
      uk: 6,
      us: 2,
    ),
    SizeRow(
      size: 36,
      bust: 84,
      waist: 68,
      hip: 92,
      backWaist: 40.5,
      uk: 8,
      us: 4,
    ),
    SizeRow(
      size: 38,
      bust: 88,
      waist: 72,
      hip: 96,
      backWaist: 41.0,
      uk: 10,
      us: 6,
    ),
    SizeRow(
      size: 40,
      bust: 92,
      waist: 76,
      hip: 100,
      backWaist: 41.5,
      uk: 12,
      us: 8,
    ),
    SizeRow(
      size: 42,
      bust: 96,
      waist: 80,
      hip: 104,
      backWaist: 42.0,
      uk: 14,
      us: 10,
    ),
    SizeRow(
      size: 44,
      bust: 100,
      waist: 84,
      hip: 108,
      backWaist: 42.5,
      uk: 16,
      us: 12,
    ),
    SizeRow(
      size: 46,
      bust: 104,
      waist: 88,
      hip: 112,
      backWaist: 43.0,
      uk: 18,
      us: 14,
    ),
    SizeRow(
      size: 48,
      bust: 110,
      waist: 94,
      hip: 118,
      backWaist: 43.5,
      uk: 20,
      us: 16,
    ),
    SizeRow(
      size: 50,
      bust: 116,
      waist: 100,
      hip: 124,
      backWaist: 44.0,
      uk: 22,
      us: 18,
    ),
    SizeRow(
      size: 52,
      bust: 122,
      waist: 106,
      hip: 130,
      backWaist: 44.5,
      uk: 24,
      us: 20,
    ),
  ];

  /// Wearing ease at the bust, for a blouse or a dress.
  ///
  /// A guide for a pattern she has not cut yet. Every Burda pattern prints its
  /// own finished measurements and those are the ones that count.
  static const List<EaseBand> ease = [
    EaseBand('Close', 'up to 7.5 cm'),
    EaseBand('Fitted', '7.5 to 10 cm'),
    EaseBand('Semi fitted', '10 to 13 cm'),
    EaseBand('Loose', '13 to 20 cm'),
    EaseBand('Very loose', 'over 20 cm'),
  ];

  /// How far past the ends of the table a measurement can be and still be given
  /// a size: one size step. Further out and the honest answer is that she is
  /// off the chart, not that she is a 52.
  static const double beyond = 6;

  /// Blouses, dresses, jackets and coats, which Burda takes from the bust.
  static int? sizeForBust(double cm) => _nearest(cm, (row) => row.bust);

  /// Skirts and trousers, which Burda takes from the hip.
  static int? sizeForHip(double cm) => _nearest(cm, (row) => row.hip);

  static SizeRow? rowFor(int size) {
    for (final row in rows) {
      if (row.size == size) return row;
    }
    return null;
  }

  static int? _nearest(double cm, double Function(SizeRow) of) {
    if (cm < of(rows.first) - beyond || cm > of(rows.last) + beyond) {
      return null;
    }
    var best = rows.first;
    for (final row in rows) {
      // Not less than, so a measurement sitting exactly between two rows takes
      // the larger: a seam can be taken in and it cannot be let out.
      if ((of(row) - cm).abs() <= (of(best) - cm).abs()) best = row;
    }
    return best.size;
  }
}

/// A centimetre value as a table prints it: "92", and "41.5" only when the half
/// is real.
String centimetres(double value) =>
    value == value.roundToDouble() ? '${value.round()}' : '$value';
