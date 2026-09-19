import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/garment_tag.dart';
import '../models/make.dart';
import '../services/database_service.dart';
import '../services/photo_relink_service.dart';

/// The sewing journal, held in memory beside the collection.
///
/// A few dozen rows at most, so the whole table is loaded once and mutated in
/// place, the way [MagazineProvider] holds the issues.
class MakeProvider extends ChangeNotifier {
  MakeProvider({DatabaseService? database})
    : _database = database ?? DatabaseService.instance;

  final DatabaseService _database;
  static const _uuid = Uuid();

  List<Make> _makes = const [];
  bool _isLoading = true;

  /// Newest first, by whatever last happened to each.
  List<Make> get makes => _makes;
  bool get isLoading => _isLoading;

  int get count => _makes.length;
  int get finishedCount => made.length;
  int get queuedCount => queued.length;
  int get photoCount => _makes.fold(0, (sum, make) => sum + make.photos.length);

  /// Cutting and sewing: the two that are waiting on her.
  List<Make> get onTheGo =>
      _makes.where((make) => make.status.isUnderway).toList();

  /// What she means to make next, in her order: most recently stamped first,
  /// which is what [moveUp] re-stamps to rearrange.
  List<Make> get queued =>
      _makes.where((make) => make.status.isQueued).toList();

  /// True when this issue is already waiting to be sewn from.
  bool isQueued(String magazineId) => _makes.any(
    (make) => make.magazineId == magazineId && make.status.isQueued,
  );

  List<Make> get made => _makes.where((make) => make.status.isDone).toList();

  List<Make> forIssue(String magazineId) =>
      _makes.where((make) => make.magazineId == magazineId).toList();

  /// How many makes came out of one issue, for a line that has to choose its
  /// words.
  int madeCountFor(String magazineId) => forIssue(magazineId).length;

  Make? byId(String id) {
    for (final make in _makes) {
      if (make.id == id) return make;
    }
    return null;
  }

  /// Every photo filed under a make, each with the make it belongs to.
  ///
  /// The same shape as `MagazineProvider.vaultPhotos`, so the vault can lay the
  /// two out side by side.
  List<({Make make, String path})> get photos => [
    for (final make in _makes)
      for (final path in make.photos) (make: make, path: path),
  ];

  Future<void> load() async {
    _makes = await _database.getMakes();
    _isLoading = false;
    notifyListeners();
  }

  Future<Make> addMake({
    String? magazineId,
    String patternNo = '',
    GarmentTag? garment,
    String size = '',
    String fabric = '',
    String notes = '',
    DateTime? queuedOn,
  }) async {
    final make = Make(
      id: _uuid.v4(),
      magazineId: magazineId,
      patternNo: patternNo,
      garment: garment,
      size: size,
      fabric: fabric,
      notes: notes,
      queuedOn: queuedOn ?? DateTime.now(),
    );
    await _database.addMake(make);
    _makes = [..._makes, make]..sort(DatabaseService.compareByMade);
    notifyListeners();
    return make;
  }

  Future<void> updateMake(Make make) async {
    await _database.updateMake(make);
    _replace(make);
  }

  /// Puts an issue in the sew queue, as a make with nothing written down yet.
  Future<Make> queueIssue(String magazineId, {DateTime? now}) =>
      addMake(magazineId: magazineId, queuedOn: now);

  /// Takes one out of the queue altogether.
  ///
  /// Only ever a queued make: once something has been cut it is a garment in
  /// progress, and that is removed from its own page where she can see what she
  /// is giving up.
  Future<void> unqueue(String id) async {
    final make = byId(id);
    if (make == null || !make.status.isQueued) return;
    await deleteMake(id);
  }

  /// Moves one up the queue by a hair.
  ///
  /// The order is the stamp, so passing the row above means taking a
  /// microsecond off its stamp rather than keeping a position column that every
  /// other write would have to maintain.
  Future<void> moveUp(String id) async {
    final order = queued;
    final at = order.indexWhere((make) => make.id == id);
    if (at <= 0) return;
    final above = order[at - 1];
    await updateMake(
      order[at].copyWith(
        queuedOn: above.queuedOn.add(const Duration(microseconds: 1)),
      ),
    );
  }

  /// Moves a make along, with the dates that move implies.
  Future<Make?> setStatus(String id, MakeStatus status, {DateTime? now}) async {
    final make = byId(id);
    if (make == null) return null;
    final updated = make.withStatus(status, now: now);
    await _database.updateMake(updated);
    _replace(updated);
    return updated;
  }

  Future<void> addPhoto(String id, String path) async {
    final make = byId(id);
    if (make == null || make.photos.contains(path)) return;
    await updateMake(make.copyWith(photos: [...make.photos, path]));
  }

  Future<void> removePhoto(String id, String path) async {
    final make = byId(id);
    if (make == null) return;
    await updateMake(
      make.copyWith(
        photos: make.photos.where((photo) => photo != path).toList(),
      ),
    );
  }

  Future<void> deleteMake(String id) async {
    await _database.deleteMake(id);
    _makes = _makes.where((make) => make.id != id).toList();
    notifyListeners();
  }

  /// Writes back photo paths repaired after an import.
  Future<void> applyRelink(List<RelinkedMake> changes) async {
    for (final change in changes) {
      final make = byId(change.id);
      if (make == null) continue;
      final updated = make.copyWith(photos: change.photos);
      await _database.updateMake(updated);
      _replace(updated);
    }
  }

  Future<int> import(List<Object?> entries) async {
    final count = await _database.importMakes(entries);
    await load();
    return count;
  }

  List<Map<String, Object?>> toExportJson() =>
      _makes.map((make) => make.toJson()).toList();

  /// Re-sorts as it writes: a status change moves a make between groups, and
  /// what it is filed under moves with it.
  void _replace(Make make) {
    _makes = [
      for (final existing in _makes)
        if (existing.id == make.id) make else existing,
    ]..sort(DatabaseService.compareByMade);
    notifyListeners();
  }
}
