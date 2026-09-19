import 'package:flutter/foundation.dart';

import '../models/garment_tag.dart';
import '../models/measurements.dart';
import '../services/database_service.dart';

/// Her measurements, held the way the collection is held: read once, kept in
/// memory, written through.
///
/// In the database rather than in shared_preferences because these have to ride
/// along in the export. Everything in this app lives on this phone and leaves
/// only through that one file, and a measurement left behind in preferences is
/// a measurement lost on the next phone. The edition and the season stay in
/// preferences, because those describe the device and not the collection.
class MeasureProvider extends ChangeNotifier {
  MeasureProvider({DatabaseService? database})
    : _database = database ?? DatabaseService.instance;

  final DatabaseService _database;

  Measurements _measurements = Measurements.none;
  bool _isLoading = true;

  Measurements get measurements => _measurements;
  bool get isLoading => _isLoading;

  /// The size to offer on a make of [tag]. Null until she has been measured.
  ///
  /// A suggestion for an empty field, never a correction to a filled one: what
  /// she cut is a fact about that garment, and half the time the pattern's own
  /// table beat this one.
  int? sizeFor(GarmentTag tag) => _measurements.sizeFor(tag);

  Future<void> load() async {
    _measurements = Measurements.fromSettings(await _database.getSettings());
    _isLoading = false;
    notifyListeners();
  }

  /// Writes every key in one batch and stamps the day they were taken.
  Future<void> save(Measurements taken, {DateTime? now}) async {
    final stamped = Measurements(
      bust: taken.bust,
      waist: taken.waist,
      hip: taken.hip,
      backWaist: taken.backWaist,
      height: taken.height,
      chosenSize: taken.chosenSize,
      takenOn: now ?? DateTime.now(),
    );
    await _database.writeSettings(stamped.toSettings(), now: stamped.takenOn);
    _measurements = stamped;
    notifyListeners();
  }

  /// Every setting in the app, for the export.
  ///
  /// The whole table rather than this feature's own keys. The day the shelf was
  /// completed and the shuffle's deck live here too, and a backup that left
  /// them behind would lose the one fact in the app that cannot be worked out
  /// again from anything else.
  Future<Map<String, String>> exportSettings() => _database.getSettings();

  /// Writes an imported settings map back, whatever it holds, and re-reads.
  ///
  /// Keys this build has never heard of are written too: a file from a later
  /// build restored here keeps whatever that build knew, rather than losing it
  /// on the way through.
  Future<void> import(Map<String, Object?> settings) async {
    final values = {
      for (final MapEntry(:key, :value) in settings.entries)
        if (value is String) key: value,
    };
    if (values.isEmpty) return;
    await _database.writeSettings(values);
    await load();
  }
}
