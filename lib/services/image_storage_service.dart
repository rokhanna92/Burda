import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Keeps the photos attached to issues, one folder per issue, under the app's
/// documents directory. The database stores their paths.
abstract final class ImageStorageService {
  static const String folder = 'magazine_images';

  /// Covers the user picked for issues that ship no artwork.
  static const String coverFolder = 'magazine_covers';

  static Future<Directory> _directoryFor(String magazineId) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(documents.path, folder, magazineId));
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  /// Copies [sourcePath] into the issue's folder and returns the new path.
  static Future<String> save({
    required String magazineId,
    required String sourcePath,
    DateTime? now,
  }) async {
    final directory = await _directoryFor(magazineId);
    final stamp = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final extension = p.extension(sourcePath).isEmpty
        ? '.jpg'
        : p.extension(sourcePath);
    final target = p.join(directory.path, '$stamp$extension');
    await File(sourcePath).copy(target);
    return target;
  }

  /// Copies [sourcePath] in as the cover for [magazineId] and returns its path.
  static Future<String> saveCover({
    required String magazineId,
    required String sourcePath,
  }) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(documents.path, coverFolder));
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    final extension = p.extension(sourcePath).isEmpty
        ? '.jpg'
        : p.extension(sourcePath);
    final target = p.join(directory.path, '$magazineId$extension');
    await File(sourcePath).copy(target);
    return target;
  }

  /// Where a photo called [name] would sit for [magazineId].
  ///
  /// Does not create anything, and does not promise the file is there: it is
  /// for looking, not for writing.
  static Future<String> photoPathFor({
    required String magazineId,
    required String name,
  }) async {
    final documents = await getApplicationDocumentsDirectory();
    return p.join(documents.path, folder, magazineId, name);
  }

  /// Where a cover called [name] would sit.
  static Future<String> coverPathFor({required String name}) async {
    final documents = await getApplicationDocumentsDirectory();
    return p.join(documents.path, coverFolder, name);
  }

  /// Deletes the file if it is still there. Returns true when it is gone.
  static Future<bool> delete(String path) async {
    final file = File(path);
    if (!file.existsSync()) return true;
    try {
      await file.delete();
      return true;
    } on FileSystemException {
      return false;
    }
  }

  /// Drops paths whose file no longer exists, so a deleted photo cannot leave
  /// a broken thumbnail behind.
  static List<String> existing(List<String> paths) =>
      paths.where((path) => File(path).existsSync()).toList();
}
