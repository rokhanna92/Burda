import 'package:flutter/foundation.dart';

import '../models/collector_rank.dart';
import '../models/endgame.dart';
import '../models/magazine.dart';
import '../models/series.dart';
import '../services/database_service.dart';
import '../services/photo_relink_service.dart';

/// Holds the whole collection in memory and derives every stat from it.
///
/// The original app re-queried SQLite from a `FutureBuilder` on most screens.
/// 184 rows fit in memory comfortably, so this loads once and mutates the list
/// in place, which is why screens can rebuild without touching the database.
class MagazineProvider extends ChangeNotifier {
  MagazineProvider({DatabaseService? database})
    : _database = database ?? DatabaseService.instance;

  final DatabaseService _database;

  List<Magazine> _magazines = const [];
  bool _isLoading = true;
  DateTime? _completedOn;

  List<Magazine> get magazines => _magazines;
  bool get isLoading => _isLoading;

  /// The day the main line was first finished, or null while it never has been.
  DateTime? get completedOn => _completedOn;

  Future<void> load({DateTime? now}) async {
    _magazines = await _database.getAllMagazines();
    final stored = await _database.getSetting(Endgame.completedOnKey);
    _completedOn = stored == null ? null : DateTime.tryParse(stored);
    _isLoading = false;
    // A collection that arrives finished, from an import or from the first load
    // after this shipped, is stamped with the day the app first saw it whole. A
    // date a little late beats a finished collection with no date at all.
    await markComplete(now: now);
    notifyListeners();
  }

  /// Where the main line stands: the only shelf whose end the app knows.
  ///
  /// The whole endgame reads this one getter, so when other shelves land it is
  /// the only line that moves. A shelf she fills by hand holds only issues she
  /// has, so it is complete the day she starts it and can never be what
  /// "complete" means. [totalCount], [ownedCount] and [completion] keep meaning
  /// the whole library, which is what the rank ladder wants.
  MainLine get mainLine {
    // The one line that changed when the shelves landed. A shelf she fills by
    // hand holds only issues she has, so it is complete the day she starts it
    // and can never be what "complete" means.
    final rows = _magazines.where((m) => m.series == Series.style);
    return (
      owned: rows.where((m) => m.isOwned).length,
      total: rows.length,
      missing: rows.where((m) => !m.isOwned).toList(growable: false),
      years: rows.map((m) => m.year).toSet().toList()..sort(),
    );
  }

  /// What one shelf holds.
  Shelf shelfFor(Series series) {
    final rows = _magazines.where((m) => m.series == series);
    return Shelf(
      series: series,
      owned: rows.where((m) => m.isOwned).length,
      total: rows.length,
      years: rows.map((m) => m.year).toSet().toList()..sort(),
    );
  }

  /// Every shelf with anything on it, in the order the enum prints them.
  List<Shelf> get startedShelves => [
    for (final series in Series.values)
      if (shelfFor(series) case final shelf when shelf.started) shelf,
  ];

  /// True once the collection is more than the main line, which is what gates
  /// every shelf heading in the app: with one shelf nothing is drawn at all.
  bool get manyShelves => startedShelves.length > 1;

  /// The shelf the headline percentage is about.
  Shelf get headline => shelfFor(Series.style);

  /// How close the main line is to finished.
  Endgame get endgame {
    final line = mainLine;
    return Endgame.of(
      total: line.total,
      missing: line.missing,
      completedOn: _completedOn,
    );
  }

  /// Records the day the main line was finished, the first time it is.
  ///
  /// Returns true when this call is the one that wrote it, which is how the
  /// celebration knows whether to say it for the first time or say it again.
  /// Giving an issue up afterwards does not clear the date and finishing again
  /// does not move it: it is when it was done, not when it was last true.
  Future<bool> markComplete({DateTime? now}) async {
    if (_completedOn != null) return false;
    final line = mainLine;
    if (line.total == 0 || line.missing.isNotEmpty) return false;
    _completedOn = now ?? DateTime.now();
    await _database.setSetting(
      Endgame.completedOnKey,
      _completedOn!.toIso8601String(),
    );
    notifyListeners();
    return true;
  }

  // Derived collection stats

  int get totalCount => _magazines.length;
  int get ownedCount => _magazines.where((m) => m.isOwned).length;
  int get missingCount => totalCount - ownedCount;

  /// Completion as a fraction between 0 and 1.
  double get completion => totalCount == 0 ? 0 : ownedCount / totalCount;

  List<Magazine> get owned => _magazines.where((m) => m.isOwned).toList();
  List<Magazine> get missing => _magazines.where((m) => !m.isOwned).toList();

  /// Every issue out of the house, longest gone first.
  ///
  /// The order is the point: the one she is most likely to have forgotten is
  /// the one at the top of the list. Nothing above this line learns the word
  /// "lent", because a lent issue is still owned, still counted and still
  /// filled in on its volume.
  List<Magazine> get lent =>
      _magazines.where((m) => m.isLent).toList()..sort((a, b) {
        final left = a.lentOn, right = b.lentOn;
        if (left == null || right == null) return 0;
        return left.compareTo(right);
      });

  int get lentCount => _magazines.where((m) => m.isLent).length;

  /// Every issue printed in [month], oldest year first.
  ///
  /// The issue number is the month on a shelf that runs twelve to a year, so
  /// "every May" costs a filter rather than a query. A shelf that does not run
  /// twelve to a year has no months to speak of and never appears here: a
  /// Special's third issue is not March.
  List<Magazine> magazinesForMonth(int month) =>
      [
        for (final magazine in _magazines)
          if (magazine.series.perYear == 12 && magazine.issue == month)
            magazine,
      ]..sort((a, b) {
        final byYear = a.year.compareTo(b.year);
        return byYear != 0 ? byYear : a.series.index.compareTo(b.series.index);
      });

  int ownedCountForMonth(int month) =>
      magazinesForMonth(month).where((m) => m.isOwned).length;

  /// Share of [month]'s issues that are owned, between 0 and 1.
  double completionForMonth(int month) {
    final issues = magazinesForMonth(month);
    if (issues.isEmpty) return 0;
    return issues.where((m) => m.isOwned).length / issues.length;
  }

  /// Years present on the main line, oldest first.
  List<int> get years => mainLine.years;

  List<Magazine> magazinesForYear(int year, {Series series = Series.style}) =>
      _magazines.where((m) => m.year == year && m.series == series).toList();

  int ownedCountForYear(int year, {Series series = Series.style}) =>
      magazinesForYear(year, series: series).where((m) => m.isOwned).length;

  int missingCountForYear(int year, {Series series = Series.style}) =>
      magazinesForYear(year, series: series).where((m) => !m.isOwned).length;

  /// Share of [year]'s issues that are owned, between 0 and 1.
  double completionForYear(int year, {Series series = Series.style}) {
    final issues = magazinesForYear(year, series: series);
    if (issues.isEmpty) return 0;
    return issues.where((m) => m.isOwned).length / issues.length;
  }

  /// True when every issue of [year] is owned.
  bool isYearComplete(int year, {Series series = Series.style}) {
    final issues = magazinesForYear(year, series: series);
    return issues.isNotEmpty && issues.every((m) => m.isOwned);
  }

  /// The eight issues added most recently, for the index's rail.
  ///
  /// An owned issue with no date, which is how an import from the original app
  /// arrives, sorts to the back rather than the front.
  List<Magazine> get recentlyAdded {
    final sorted = owned
      ..sort((a, b) {
        final left = a.dateAdded, right = b.dateAdded;
        if (left == null && right == null) return 0;
        if (left == null) return 1;
        if (right == null) return -1;
        return right.compareTo(left);
      });
    return sorted.take(8).toList(growable: false);
  }

  /// How many years of the main line are owned end to end.
  int get completeYearCount => years.where((y) => isYearComplete(y)).length;

  /// Most recent moment an issue was marked owned.
  DateTime? get latestAddition {
    final dates = owned.map((m) => m.dateAdded).whereType<DateTime>().toList();
    if (dates.isEmpty) return null;
    return dates.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// Earliest year in the collection, owned or not.
  int? get oldestIssueYear => years.isEmpty ? null : years.first;

  /// Photos attached across every issue.
  int get vaultCount =>
      _magazines.fold(0, (sum, m) => sum + m.uploadedImages.length);

  /// Every photo in the collection, each with the issue it belongs to.
  List<({Magazine magazine, String path})> get vaultPhotos => [
    for (final magazine in _magazines)
      for (final path in magazine.uploadedImages)
        (magazine: magazine, path: path),
  ];

  /// Average condition of the issues that have been rated, or null if none are.
  double? get averageCondition {
    final scores = owned.map((m) => m.conditionScore).whereType<int>().toList();
    if (scores.isEmpty) return null;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  CollectorRank get rank => CollectorRank.forOwnedCount(ownedCount);

  Magazine? byId(String id) => _magazines.firstWhereOrNull((m) => m.id == id);

  /// Best first: her marks lead, then the higher score, then the newest volume,
  /// then the issue number.
  ///
  /// A favourite with no score sorts above an unmarked ten, because the mark is
  /// the judgment she made unprompted and the score is the one she was asked
  /// for. Static, like [DatabaseService.compareByIssue], so a screen can sort a
  /// list it already filtered rather than asking for a second one.
  static int compareByRating(Magazine a, Magazine b) {
    if (a.isFavourite != b.isFavourite) return a.isFavourite ? -1 : 1;
    final byScore = (b.contentScore ?? 0).compareTo(a.contentScore ?? 0);
    if (byScore != 0) return byScore;
    final byYear = b.year.compareTo(a.year);
    return byYear != 0 ? byYear : a.issue.compareTo(b.issue);
  }

  // Mutations

  /// Returns true when the issue is now owned.
  Future<bool> toggleOwnership(String id) async {
    final updated = await _database.toggleOwnership(id);
    if (updated == null) return false;
    _replace(updated);
    return updated.isOwned;
  }

  Future<void> setCondition(String id, int score) async {
    final updated = await _database.setCondition(id, score);
    if (updated != null) _replace(updated);
  }

  Future<void> lendIssue(String id, String to) async {
    final updated = await _database.lendIssue(id, to);
    if (updated != null) _replace(updated);
  }

  Future<void> returnIssue(String id) async {
    final updated = await _database.returnIssue(id);
    if (updated != null) _replace(updated);
  }

  Future<void> setContentScore(String id, int score) async {
    final updated = await _database.setContentScore(id, score);
    if (updated != null) _replace(updated);
  }

  /// Returns true when the issue now carries her mark.
  Future<bool> toggleFavourite(String id) async {
    final updated = await _database.toggleFavourite(id);
    if (updated == null) return false;
    _replace(updated);
    return updated.isFavourite;
  }

  Future<void> addMagazine(Magazine magazine) async {
    await _database.addMagazine(magazine);
    _magazines = [..._magazines, magazine]
      ..sort(DatabaseService.compareByIssue);
    notifyListeners();
  }

  Future<void> deleteMagazine(String id) async {
    await _database.deleteMagazine(id);
    _magazines = _magazines.where((m) => m.id != id).toList();
    notifyListeners();
  }

  Future<void> addUploadedImage(String id, String path) async {
    final updated = await _database.addUploadedImage(id, path);
    if (updated != null) _replace(updated);
  }

  Future<void> removeUploadedImage(String id, String path) async {
    final updated = await _database.removeUploadedImage(id, path);
    if (updated != null) _replace(updated);
  }

  /// Writes back photo and cover paths repaired after an import.
  Future<void> applyRelink(List<RelinkedIssue> changes) async {
    for (final change in changes) {
      final magazine = byId(change.id);
      if (magazine == null) continue;
      final updated = magazine.copyWith(
        image: change.cover,
        uploadedImages: change.photos,
      );
      await _database.updateMagazine(updated);
      _replace(updated);
    }
  }

  /// Applies an exported collection and reloads from the database.
  Future<int> import(List<Object?> entries) async {
    final count = await _database.importMagazines(entries);
    await load();
    return count;
  }

  /// The export payload: every issue, newest schema shape.
  List<Map<String, Object?>> toExportJson() =>
      _magazines.map((m) => m.toJson()).toList();

  void _replace(Magazine magazine) {
    _magazines = [
      for (final existing in _magazines)
        if (existing.id == magazine.id) magazine else existing,
    ];
    notifyListeners();
  }
}

extension _FirstWhereOrNull<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
