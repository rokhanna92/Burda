import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Keeps the photos the app is given, one folder per kind and, inside it, one
/// folder per issue. The database stores their paths.
abstract final class ImageStorageService {
  /// Photos of what she made: the vault.
  static const String folder = 'magazine_images';

  /// Covers the user picked for issues that ship no artwork.
  static const String coverFolder = 'magazine_covers';

  /// Photographs of the issue's own pages: its contents spread, its pattern
  /// sheets. A folder of its own, beside [folder], because the vault is what
  /// she made and this is what the magazine printed. Two folders make the two
  /// impossible to confuse rather than merely unlikely.
  static const String contentsFolder = 'contents_pages';

  /// `documents/<folder>/<owner>/`, made if it is not there yet.
  static Future<Directory> _directoryFor(String folder, String owner) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(documents.path, folder, owner));
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  /// Copies [sourcePath] into [directory] and returns the new path.
  ///
  /// The name is the millisecond it arrived in, unless one is given, which
  /// keeps two photos of the same issue apart without asking her to name them.
  static Future<String> _copyInto(
    Directory directory,
    String sourcePath, {
    String? name,
    DateTime? now,
  }) async {
    final extension = p.extension(sourcePath).isEmpty
        ? '.jpg'
        : p.extension(sourcePath);
    final stem = name ?? '${(now ?? DateTime.now()).millisecondsSinceEpoch}';
    final target = p.join(directory.path, '$stem$extension');
    await File(sourcePath).copy(target);
    return target;
  }

  /// Copies [sourcePath] into the issue's vault folder and returns the new path.
  static Future<String> save({
    required String magazineId,
    required String sourcePath,
    DateTime? now,
  }) async =>
      _copyInto(await _directoryFor(folder, magazineId), sourcePath, now: now);

  /// Copies [sourcePath] in as one of the issue's photographed pages.
  static Future<String> saveContentsPage({
    required String magazineId,
    required String sourcePath,
    DateTime? now,
  }) async => _copyInto(
    await _directoryFor(contentsFolder, magazineId),
    sourcePath,
    now: now,
  );

  /// Copies [sourcePath] in as the cover for [magazineId] and returns its path.
  ///
  /// Named after the issue rather than the clock: there is only ever one, and a
  /// second pick should land on top of the first rather than beside it.
  static Future<String> saveCover({
    required String magazineId,
    required String sourcePath,
  }) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(documents.path, coverFolder));
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return _copyInto(directory, sourcePath, name: magazineId);
  }

  /// Where a vault photo called [name] would sit for [magazineId].
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

  /// Where a photographed page called [name] would sit for [magazineId].
  static Future<String> contentsPathFor({
    required String magazineId,
    required String name,
  }) async {
    final documents = await getApplicationDocumentsDirectory();
    return p.join(documents.path, contentsFolder, magazineId, name);
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
