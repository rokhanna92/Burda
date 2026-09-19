import 'package:flutter/foundation.dart';

import 'garment_tag.dart';
import 'size_chart.dart';

abstract final class MeasureKeys {
  /// Everything this feature owns in the settings table. An import takes the
  /// keys under it and leaves every other feature's alone.
  static const String prefix = 'measure.';

  static const String bust = 'measure.bust';
  static const String waist = 'measure.waist';
  static const String hip = 'measure.hip';

  /// Named backWaist rather than backLength because that is the key the schema
  /// fixed, and a key is never renamed once her phone has written one.
  static const String backWaist = 'measure.backWaist';
  static const String height = 'measure.height';
  static const String size = 'measure.burdaSize';
  static const String takenOn = 'measure.takenOn';
}

/// The five numbers, and the size they come to.
///
/// One value rather than five separate settings, because measurements are taken
/// together with a tape in hand: a bust from today beside a hip from last year
/// is not a set of measurements, it is two facts about two people.
@immutable
class Measurements {
  const Measurements({
    this.bust,
    this.waist,
    this.hip,
    this.backWaist,
    this.height,
    this.chosenSize,
    this.takenOn,
  });

  static const Measurements none = Measurements();

  /// Centimetres. Null until she has been measured.
  final double? bust;
  final double? waist;
  final double? hip;

  /// Nape of the neck to the waist.
  final double? backWaist;
  final double? height;

  /// The size she cuts, whatever the chart says.
  ///
  /// Absent until she disagrees with it. The chart is a good guess from four
  /// numbers; thirty years of cutting Burda is better, and the pattern's own
  /// table beat both on the day she found out.
  final int? chosenSize;

  /// The day the numbers were taken, all together.
  final DateTime? takenOn;

  bool get isTaken =>
      bust != null ||
      waist != null ||
      hip != null ||
      backWaist != null ||
      height != null;

  int? get chartTopSize => bust == null ? null : SizeChart.sizeForBust(bust!);
  int? get chartSkirtSize => hip == null ? null : SizeChart.sizeForHip(hip!);

  /// Blouses, dresses, jackets and coats.
  int? get topSize => chosenSize ?? chartTopSize;

  /// Skirts and trousers.
  int? get skirtSize => chosenSize ?? chartSkirtSize;

  /// The size the page leads with.
  int? get size => topSize;

  /// The size to put in front of her on a make of [tag].
  int? sizeFor(GarmentTag tag) => switch (tag) {
    GarmentTag.skirt || GarmentTag.trousers => skirtSize,
    _ => topSize,
  };

  SizeRun get run => SizeRun.forHeight(height);

  /// Her line of the chart, when she has one.
  SizeRow? get row => size == null ? null : SizeChart.rowFor(size!);

  /// True when a bust was measured but it falls outside Burda's table.
  bool get offChart =>
      chosenSize == null && bust != null && chartTopSize == null;

  factory Measurements.fromSettings(Map<String, String> settings) =>
      Measurements(
        bust: _number(settings[MeasureKeys.bust]),
        waist: _number(settings[MeasureKeys.waist]),
        hip: _number(settings[MeasureKeys.hip]),
        backWaist: _number(settings[MeasureKeys.backWaist]),
        height: _number(settings[MeasureKeys.height]),
        chosenSize: int.tryParse(settings[MeasureKeys.size] ?? ''),
        takenOn: DateTime.tryParse(settings[MeasureKeys.takenOn] ?? ''),
      );

  /// What to write.
  ///
  /// A null value clears that key, which is how a number she rubbed out stops
  /// being hers. Every entry is written, nulls included: leaving one out would
  /// mean the old number quietly survived, and the sheet promises it does not.
  Map<String, String?> toSettings() => {
    MeasureKeys.bust: _write(bust),
    MeasureKeys.waist: _write(waist),
    MeasureKeys.hip: _write(hip),
    MeasureKeys.backWaist: _write(backWaist),
    MeasureKeys.height: _write(height),
    MeasureKeys.size: chosenSize == null ? null : '$chosenSize',
    MeasureKeys.takenOn: isTaken ? takenOn?.toIso8601String() : null,
  };

  /// Cannot clear a field: an empty one means "I did not measure that", and
  /// that answer comes from the sheet building a whole [Measurements] out of
  /// its six boxes rather than from patching this one.
  Measurements copyWith({
    double? bust,
    double? waist,
    double? hip,
    double? backWaist,
    double? height,
    int? chosenSize,
    DateTime? takenOn,
  }) => Measurements(
    bust: bust ?? this.bust,
    waist: waist ?? this.waist,
    hip: hip ?? this.hip,
    backWaist: backWaist ?? this.backWaist,
    height: height ?? this.height,
    chosenSize: chosenSize ?? this.chosenSize,
    takenOn: takenOn ?? this.takenOn,
  );

  /// A decimal comma is what the tape measure and the keyboard both give here,
  /// so it reads the same as a point. Only a point is ever written.
  static double? _number(String? value) =>
      value == null ? null : double.tryParse(value.replaceAll(',', '.'));

  static String? _write(double? value) =>
      value == null ? null : centimetres(value);
}
