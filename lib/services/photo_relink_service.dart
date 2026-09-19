import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/magazine.dart';
import 'image_storage_service.dart';

/// What a relink pass managed to do.
class RelinkReport {
  const RelinkReport({
    this.alreadyThere = 0,
    this.relinked = 0,
    this.copied = 0,
    this.lost = 0,
  });

  /// Photos whose stored path was still good.
  final int alreadyThere;

  /// Photos found under this app's own folders and re-pointed.
  final int relinked;

  /// Photos copied in from a folder the user pointed at.
  final int copied;

  /// Photos that could not be found anywhere.
  final int lost;

  int get recovered => relinked + copied;
  bool get anyLost => lost > 0;

  RelinkReport operator +(RelinkReport other) => RelinkReport(
    alreadyThere: alreadyThere + other.alreadyThere,
    relinked: relinked + other.relinked,
    copied: copied + other.copied,
    lost: lost + other.lost,
  );
}

/// One issue's repaired paths.
typedef RelinkedIssue = ({String id, List<String> photos, String? cover});

/// Re-points photo paths at files that actually exist on this device.
///
/// An export carries absolute paths, and those paths belong to the phone and
/// the package name they were written on. The original app was
/// `com.example.burda`; this one is not, so every path in a file exported from
/// it points at a directory this app cannot see.
///
/// The photos themselves are not in the export, so this matches them by file
/// name: first against the folders this app already keeps, then against a
/// folder the user points at, copying anything it finds into place.
abstract final class PhotoRelinkService {
  /// Repairs [magazines], optionally drawing on [sourceFolder].
  ///
  /// Returns the issues whose paths changed, so only those need writing back.
  static Future<(List<RelinkedIssue>, RelinkReport)> repair(
    List<Magazine> magazines, {
    Directory? sourceFolder,
  }) async {
    final byName = sourceFolder == null
        ? const <String, File>{}
        : await _indexByName(sourceFolder);

    final changed = <RelinkedIssue>[];
    var report = const RelinkReport();

    for (final magazine in magazines) {
      final photos = <String>[];
      var touched = false;

      for (final path in magazine.uploadedImages) {
        final (resolved, outcome) = await _resolve(
          path: path,
          magazineId: magazine.id,
          byName: byName,
          asCover: false,
        );
        report += outcome;
        if (resolved != null) photos.add(resolved);
        if (resolved != path) touched = true;
      }

      String? cover;
      if (magazine.hasFileCover) {
        final (resolved, outcome) = await _resolve(
          path: magazine.image,
          magazineId: magazine.id,
          byName: byName,
          asCover: true,
        );
        report += outcome;
        // A lost cover of her own falls back to the artwork the app ships for
        // that issue, rather than leaving a blank tile.
        cover = resolved ?? 'covers/${magazine.id}.jpg';
        if (cover != magazine.image) touched = true;
      }

      if (touched) {
        changed.add((id: magazine.id, photos: photos, cover: cover));
      }
    }

    return (changed, report);
  }

  /// Finds one file, wherever it may now be.
  static Future<(String?, RelinkReport)> _resolve({
    required String path,
    required String magazineId,
    required Map<String, File> byName,
    required bool asCover,
  }) async {
    if (File(path).existsSync()) {
      return (path, const RelinkReport(alreadyThere: 1));
    }

    final name = p.basename(path);

    // Already sitting in this app's own folders, just under a different root:
    // the case when the whole data directory was copied across.
    final mine = await _ownCopy(name: name, magazineId: magazineId);
    if (mine != null) return (mine, const RelinkReport(relinked: 1));

    final found = byName[name];
    if (found != null) {
      final target = asCover
          ? await ImageStorageService.saveCover(
              magazineId: magazineId,
              sourcePath: found.path,
            )
          : await ImageStorageService.save(
              magazineId: magazineId,
              sourcePath: found.path,
            );
      return (target, const RelinkReport(copied: 1));
    }

    return (null, const RelinkReport(lost: 1));
  }

  /// Looks for [name] in the folders this app keeps for [magazineId].
  static Future<String?> _ownCopy({
    required String name,
    required String magazineId,
  }) async {
    for (final candidate in [
      await ImageStorageService.photoPathFor(
        magazineId: magazineId,
        name: name,
      ),
      await ImageStorageService.coverPathFor(name: name),
    ]) {
      if (File(candidate).existsSync()) return candidate;
    }
    return null;
  }

  /// Every file under [folder], by name.
  ///
  /// Later files win, which does not matter: photos are named by the
  /// millisecond they were taken in, so a clash means the same photo twice.
  static Future<Map<String, File>> _indexByName(Directory folder) async {
    final index = <String, File>{};
    if (!folder.existsSync()) return index;

    await for (final entry in folder.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entry is File) index[p.basename(entry.path)] = entry;
    }
    return index;
  }
}
