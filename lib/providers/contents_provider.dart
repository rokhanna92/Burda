import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/contents_entry.dart';
import '../models/garment_tag.dart';
import '../services/database_service.dart';
import '../services/image_storage_service.dart';
import '../services/photo_relink_service.dart';

/// Every photographed page in the collection, held in memory beside the issues.
///
/// Its own provider and its own table, not a second list on Magazine: the vault
/// is what she made, this is what the magazine printed, and the two must never
/// end up in one grid or one count. Two tables make that impossible rather than
/// merely unlikely.
class ContentsProvider extends ChangeNotifier {
  ContentsProvider({DatabaseService? database})
    : _database = database ?? DatabaseService.instance;

  final DatabaseService _database;
  static const _uuid = Uuid();

  List<ContentsEntry> _entries = const [];
  bool _isLoading = true;

  List<ContentsEntry> get entries => _entries;
  bool get isLoading => _isLoading;
  int get count => _entries.length;

  Future<void> load() async {
    _entries = await _database.getContents();
    _isLoading = false;
    notifyListeners();
  }

  /// One issue's pages, in the order they were photographed: the contents
  /// spread first and the pattern sheets after, which is the order they are
  /// bound in. The table is read ordered by [ContentsEntry.addedOn] and
  /// additions go on the end, so nothing here has to sort.
  List<ContentsEntry> forIssue(String magazineId) =>
      _entries.where((entry) => entry.magazineId == magazineId).toList();

  int countFor(String magazineId) =>
      _entries.where((entry) => entry.magazineId == magazineId).length;

  ContentsEntry? byId(String id) {
    for (final entry in _entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  /// Ids of every issue with at least one page marked [tag].
  Set<String> issuesTagged(GarmentTag tag) => {
    for (final entry in _entries)
      if (entry.tags.contains(tag)) entry.magazineId,
  };

  /// How many issues carry each word, in print order.
  ///
  /// Issues rather than pages, because two tagged pages of one issue are still
  /// one issue to go and look at. A word nothing carries is left out, so the
  /// search sheet only ever offers one that leads somewhere.
  Map<GarmentTag, int> get issueCountsByTag => {
    for (final tag in GarmentTag.values)
      if (issuesTagged(tag) case final issues when issues.isNotEmpty)
        tag: issues.length,
  };

  Future<ContentsEntry> addPage({
    required String magazineId,
    required String path,
    DateTime? now,
  }) async {
    final entry = ContentsEntry(
      id: _uuid.v4(),
      magazineId: magazineId,
      path: path,
      addedOn: now ?? DateTime.now(),
    );
    await _database.addContents(entry);
    _entries = [..._entries, entry];
    notifyListeners();
    return entry;
  }

  /// Marks or unmarks one garment on one page.
  Future<void> toggleTag(String id, GarmentTag tag) async {
    final entry = byId(id);
    if (entry == null) return;
    final tags = {...entry.tags};
    // Removing tells us whether it was there, so the word toggles in one pass.
    if (!tags.remove(tag)) tags.add(tag);
    final updated = entry.copyWith(tags: tags);
    await _database.updateContents(updated);
    _replace(updated);
  }

  /// Takes the page out of the index and its photograph off the phone.
  ///
  /// The file goes here rather than at the call site, which is where the vault
  /// deletes its own, because two screens remove pages and this is the only one
  /// of the three that knows every path.
  Future<void> removePage(String id) async {
    final entry = byId(id);
    if (entry == null) return;
    await ImageStorageService.delete(entry.path);
    await _database.deleteContents(id);
    _entries = _entries.where((entry) => entry.id != id).toList();
    notifyListeners();
  }

  /// Every page of one issue, for when the issue itself goes.
  Future<void> removeIssue(String magazineId) async {
    final going = forIssue(magazineId);
    if (going.isEmpty) return;
    for (final entry in going) {
      await ImageStorageService.delete(entry.path);
      await _database.deleteContents(entry.id);
    }
    _entries = _entries
        .where((entry) => entry.magazineId != magazineId)
        .toList();
    notifyListeners();
  }

  Future<int> import(List<Object?> entries) async {
    final count = await _database.importContents(entries);
    await load();
    return count;
  }

  List<Map<String, Object?>> toExportJson() =>
      _entries.map((entry) => entry.toJson()).toList();

  /// Writes back page paths repaired after an import.
  ///
  /// A page whose photograph could not be found keeps its row and its marks, so
  /// the search can still lead her to the issue. Only the path goes.
  Future<void> applyRelink(List<RelinkedPage> changes) async {
    for (final change in changes) {
      final entry = byId(change.id);
      if (entry == null) continue;
      final updated = entry.copyWith(path: change.path ?? '');
      await _database.updateContents(updated);
      _replace(updated);
    }
  }

  void _replace(ContentsEntry entry) {
    _entries = [
      for (final existing in _entries)
        if (existing.id == entry.id) entry else existing,
    ];
    notifyListeners();
  }
}
