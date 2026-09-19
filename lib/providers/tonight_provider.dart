import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../services/database_service.dart';

/// The one issue the index offers for the evening.
///
/// 201 issues is more than anyone's memory of them, so the shelf has a middle
/// that never gets looked at. This deals one issue, keeps it there until the
/// evening is over, and remembers what it has already dealt, so a pass shows
/// every issue she owns before it shows any of them twice.
///
/// The deck is kept in the `settings` table rather than in shared_preferences:
/// a card that forgets itself when the app is killed is not tonight's issue,
/// and what is in the database rides along in the export.
class TonightProvider extends ChangeNotifier {
  TonightProvider({DatabaseService? database, Random? random})
    : _database = database ?? DatabaseService.instance,
      _random = random ?? Random();

  /// What is on the index, and the evening it was dealt for.
  static const String tonightKey = 'deck.tonight';

  /// Every issue this pass through the shelf has already shown.
  static const String dealtKey = 'deck.dealt';

  final DatabaseService _database;

  /// Seedable, so a test can know which card it is going to get.
  final Random _random;

  String? _id;
  DateTime? _dealtOn;
  List<String> _dealt = const [];

  /// The issue on the index tonight, or null while there is nothing to deal.
  String? get id => _id;

  /// The evening [id] was dealt for.
  DateTime? get dealtOn => _dealtOn;

  /// How many issues this pass through the shelf has shown, [id] included.
  int get dealtCount => _dealt.length;

  /// The evening a moment belongs to.
  ///
  /// The day turns at four in the morning, not at midnight. She sews late, and
  /// a card that changes under her at half past twelve is not tonight's issue
  /// any more.
  static DateTime eveningOf(DateTime moment) {
    final shifted = moment.subtract(const Duration(hours: 4));
    return DateTime(shifted.year, shifted.month, shifted.day);
  }

  /// Reads the deck back, then deals if what is stored is not tonight's.
  ///
  /// It asks the database for the shelf rather than waiting on
  /// [MagazineProvider]: the two load side by side at start-up, and one more
  /// read of 201 rows is a better trade than a card that only turns up on the
  /// second launch.
  Future<void> load({DateTime? now}) async {
    final settings = await _database.getSettings();
    if (settings[tonightKey] case final stored?) {
      if (jsonDecode(stored) case Map card) {
        _id = card['id'] as String?;
        _dealtOn = DateTime.tryParse(card['dealtOn'] as String? ?? '');
      }
    }
    if (settings[dealtKey] case final stored?) {
      if (jsonDecode(stored) case List pass) _dealt = pass.cast<String>();
    }

    final shelf = await _shelf();
    final evening = eveningOf(now ?? DateTime.now());
    if (_dealtOn != evening || !shelf.contains(_id)) {
      await _deal(shelf, evening);
    }
    notifyListeners();
  }

  /// Deals again, at her asking.
  Future<void> another({DateTime? now}) async {
    await _deal(await _shelf(), eveningOf(now ?? DateTime.now()));
    notifyListeners();
  }

  /// What can be dealt: the issues she actually has.
  ///
  /// Serving her an issue she does not own is a taunt rather than a pleasure,
  /// and one at a friend's house is no more available tonight than one she
  /// never had.
  Future<List<String>> _shelf() async {
    final magazines = await _database.getAllMagazines();
    return [
      for (final magazine in magazines)
        if (magazine.isOwned && !magazine.isLent) magazine.id,
    ];
  }

  Future<void> _deal(List<String> shelf, DateTime evening) async {
    // An empty shelf is not an empty card. Clearing what is stored would throw
    // away the pass over a collection that has simply not been started.
    if (shelf.isEmpty) return;

    // An issue given up or deleted drops out of the pass instead of sitting in
    // it for ever, holding off the reshuffle. Nothing in SQL keeps a settings
    // row honest, so it is pruned here, every time one is dealt.
    final pass = _dealt.where(shelf.contains).toSet();
    var fresh = [
      for (final id in shelf)
        if (!pass.contains(id)) id,
    ];

    final reshuffled = fresh.isEmpty;
    if (reshuffled) {
      // Every issue has been dealt, so the pass starts over. The card she is
      // looking at is held back: a reshuffle that hands back the same cover
      // reads as a broken link rather than as a fresh pass.
      fresh = [
        for (final id in shelf)
          if (id != _id) id,
      ];
      if (fresh.isEmpty) fresh = shelf; // she owns exactly one issue
    }

    final pick = fresh[_random.nextInt(fresh.length)];
    _id = pick;
    _dealtOn = evening;
    _dealt = reshuffled ? [pick] : [...pass, pick];

    await _database.writeSettings({
      tonightKey: jsonEncode({'id': pick, 'dealtOn': _dateOnly(evening)}),
      dealtKey: jsonEncode(_dealt),
    });
  }

  /// `"2026-09-19"`, which [DateTime.parse] reads straight back as the same
  /// local midnight, so comparing two evenings is a plain equality.
  static String _dateOnly(DateTime day) =>
      day.toIso8601String().split('T').first;
}
