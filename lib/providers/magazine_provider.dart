import 'package:flutter/foundation.dart';

import '../models/collector_rank.dart';
import '../models/magazine.dart';
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

  List<Magazine> get magazines => _magazines;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _magazines = await _database.getAllMagazines();
    _isLoading = false;
    notifyListeners();
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

  /// Years present in the collection, oldest first.
  List<int> get years => _magazines.map((m) => m.year).toSet().toList()..sort();

  List<Magazine> magazinesForYear(int year) =>
      _magazines.where((m) => m.year == year).toList();

  int ownedCountForYear(int year) =>
      _magazines.where((m) => m.year == year && m.isOwned).length;

  int missingCountForYear(int year) =>
      _magazines.where((m) => m.year == year && !m.isOwned).length;

  /// Share of [year]'s issues that are owned, between 0 and 1.
  double completionForYear(int year) {
    final issues = magazinesForYear(year);
    if (issues.isEmpty) return 0;
    return issues.where((m) => m.isOwned).length / issues.length;
  }

  /// True when every issue of [year] is owned.
  bool isYearComplete(int year) {
    final issues = magazinesForYear(year);
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

  /// How many years are owned end to end.
  int get completeYearCount => years.where(isYearComplete).length;

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
