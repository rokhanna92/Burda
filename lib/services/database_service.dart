import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/contents_entry.dart';
import '../models/magazine.dart';
import '../models/note.dart';

/// Owns the SQLite store: the seeded `magazines` table, the `notes` table and
/// the `contents` table.
///
/// The original app kept these in two database files and carried five
/// migrations. A rebuilt install can never see those old files (it is a
/// different application id, signed with a different key), so this one starts
/// clean and existing collections come in through [importMagazines] instead.
///
/// The schema grows by a ladder of rungs rather than by a single declaration,
/// and both a fresh install and an upgrade climb it, so there is only ever one
/// description of the tables. Two descriptions drift, and the drift shows up
/// only on a phone that upgraded rather than installed, which is the one phone
/// that matters.
class DatabaseService {
  DatabaseService({
    Future<String> Function()? loadSeed,
    String databaseName = 'burda.db',
  }) : _loadSeed = loadSeed ?? _loadSeedFromAssets,
       // ignore: prefer_initializing_formals
       _databaseName = databaseName;

  static final DatabaseService instance = DatabaseService();

  /// Bumped whenever the bundled issue list grows or the schema changes.
  ///
  /// 1: the first build. 2: 2025 filled out to twelve issues and 2026 began.
  /// 3: the contents index.
  static const int schemaVersion = 3;

  static const String magazinesTable = 'magazines';
  static const String notesTable = 'notes';
  static const String contentsTable = 'contents';

  /// What each version did to the schema, in order.
  ///
  /// A rung number is allocated the day it ships, never reserved in advance,
  /// and [schemaVersion] is always the highest rung that has shipped. A rung is
  /// never edited afterwards: her phone has already run it, and the only way to
  /// change what it built is to add a rung above.
  ///
  /// The map is sparse on purpose. Version 2 only extended the bundled issue
  /// list, and the re-seed carries that on its own, so when 2027 arrives the
  /// version is bumped and no rung is added.
  static const Map<int, List<String>> _ladder = {
    1: [_createMagazines, _createNotes, _indexMagazinesYear],
    3: [_createContents],
  };

  final Future<String> Function() _loadSeed;
  final String _databaseName;

  Database? _database;

  Future<Database> get database async => _database ??= await _open();

  Future<Database> _open() async {
    final path = _databaseName == inMemoryDatabasePath
        ? _databaseName
        : p.join(await getDatabasesPath(), _databaseName);
    return openDatabase(
      path,
      version: schemaVersion,
      // A fresh install replays the ladder rather than declaring the finished
      // schema, so a phone that installed today and a phone that has upgraded
      // since the first build hold provably the same tables.
      onCreate: (db, version) async {
        await _migrate(db, from: 0, to: version);
        await _seed(db);
      },
      // The magazine keeps publishing, so the bundled list keeps growing. A
      // re-seed inserts what is new and, because it ignores conflicts, leaves
      // every row already there untouched: ownership, condition and photos all
      // survive. It runs after every upgrade, not only after the rungs that
      // changed the schema, because a version bump is sometimes nothing but a
      // longer list.
      //
      // An issue deleted by hand does come back at this point. That is the
      // trade for ever seeing a new one, and it only happens on an update that
      // extends the list.
      onUpgrade: (db, from, to) async {
        await _migrate(db, from: from, to: to);
        await _seed(db);
      },
      // onDowngrade is deliberately left unset, and onDatabaseDowngradeDelete
      // is never passed: it deletes the database file, which on this app means
      // her collection. An older build sideloaded over a newer one throws on
      // open, loudly, rather than quietly recording a lower version and then
      // replaying a rung into a duplicate column. The way back is the export.
    );
  }

  /// Runs every rung above [from] up to and including [to].
  Future<void> _migrate(
    DatabaseExecutor db, {
    required int from,
    required int to,
  }) async {
    for (var version = from + 1; version <= to; version++) {
      for (final statement in _ladder[version] ?? const <String>[]) {
        await db.execute(statement);
      }
    }
  }

  // Rung 1, the first build.

  static const String _createMagazines =
      '''
          CREATE TABLE $magazinesTable (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            year INTEGER NOT NULL,
            image TEXT NOT NULL,
            isOwned INTEGER NOT NULL DEFAULT 0,
            dateAdded TEXT,
            conditionScore INTEGER,
            uploadedImages TEXT NOT NULL DEFAULT '[]'
          )
        ''';

  static const String _createNotes =
      '''
          CREATE TABLE $notesTable (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            date TEXT NOT NULL
          )
        ''';

  static const String _indexMagazinesYear =
      'CREATE INDEX idx_magazines_year ON $magazinesTable (year)';

  // Rung 3, the contents index.
  //
  // No foreign key on magazineId, and none anywhere else either. The re-seed
  // above is meant to bring back an issue deleted by hand, and ON DELETE
  // CASCADE would quietly take that issue's photographed pages with it on the
  // way past. A soft reference resolved in Dart makes the round trip lossless.
  static const String _createContents =
      '''
          CREATE TABLE $contentsTable (
            id TEXT PRIMARY KEY,
            magazineId TEXT NOT NULL,
            path TEXT NOT NULL,
            caption TEXT NOT NULL DEFAULT '',
            tags TEXT NOT NULL DEFAULT '[]',
            addedOn TEXT NOT NULL
          )
        ''';

  /// Fills a fresh database with the bundled issue list.
  Future<void> _seed(DatabaseExecutor db) async {
    final seeds = jsonDecode(await _loadSeed()) as List;
    final batch = db.batch();
    for (final seed in seeds) {
      batch.insert(
        magazinesTable,
        Magazine.fromJson(seed as Map<String, dynamic>).toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<String> _loadSeedFromAssets() =>
      rootBundle.loadString('assets/magazines.json');

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  // Magazines

  Future<List<Magazine>> getAllMagazines() async {
    final db = await database;
    final rows = await db.query(magazinesTable);
    final magazines = rows.map(Magazine.fromMap).toList();
    magazines.sort(compareByIssue);
    return magazines;
  }

  Future<List<Magazine>> getMagazinesByYear(int year) async {
    final db = await database;
    final rows = await db.query(
      magazinesTable,
      where: 'year = ?',
      whereArgs: [year],
    );
    final magazines = rows.map(Magazine.fromMap).toList();
    magazines.sort(compareByIssue);
    return magazines;
  }

  Future<Magazine?> getMagazine(String id) async {
    final db = await database;
    final rows = await db.query(
      magazinesTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Magazine.fromMap(rows.first);
  }

  Future<void> addMagazine(Magazine magazine) async {
    final db = await database;
    await db.insert(
      magazinesTable,
      magazine.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateMagazine(Magazine magazine) async {
    final db = await database;
    await db.update(
      magazinesTable,
      magazine.toMap(),
      where: 'id = ?',
      whereArgs: [magazine.id],
    );
  }

  Future<void> deleteMagazine(String id) async {
    final db = await database;
    await db.delete(magazinesTable, where: 'id = ?', whereArgs: [id]);
  }

  /// Flips owned state, stamping [dateAdded] when an issue is gained and
  /// clearing it when it is given up.
  Future<Magazine?> toggleOwnership(String id, {DateTime? now}) async {
    final magazine = await getMagazine(id);
    if (magazine == null) return null;
    final owned = !magazine.isOwned;
    // Setting an issue aside clears its condition along with its date, as the
    // design does: the score describes a copy that is no longer held.
    final updated = owned
        ? magazine.copyWith(isOwned: true, dateAdded: now ?? DateTime.now())
        : magazine.copyWith(
            isOwned: false,
            clearDateAdded: true,
            clearConditionScore: true,
          );
    await updateMagazine(updated);
    return updated;
  }

  /// Stores a 1 to 10 condition score.
  Future<Magazine?> setCondition(String id, int score) async {
    final magazine = await getMagazine(id);
    if (magazine == null) return null;
    final updated = magazine.copyWith(conditionScore: score.clamp(1, 10));
    await updateMagazine(updated);
    return updated;
  }

  Future<Magazine?> addUploadedImage(String id, String path) async {
    final magazine = await getMagazine(id);
    if (magazine == null) return null;
    if (magazine.uploadedImages.contains(path)) return magazine;
    final updated = magazine.copyWith(
      uploadedImages: [...magazine.uploadedImages, path],
    );
    await updateMagazine(updated);
    return updated;
  }

  Future<Magazine?> removeUploadedImage(String id, String path) async {
    final magazine = await getMagazine(id);
    if (magazine == null) return null;
    final updated = magazine.copyWith(
      uploadedImages: magazine.uploadedImages
          .where((image) => image != path)
          .toList(),
    );
    await updateMagazine(updated);
    return updated;
  }

  /// Merges an exported collection back in, keeping issues the export does not
  /// mention. Returns how many rows were written.
  ///
  /// REPLACE deletes the row it is replacing before writing the new one. That
  /// is harmless while nothing references an issue by a real foreign key. If
  /// one is ever added with ON DELETE CASCADE, this has to become an UPDATE
  /// followed by an INSERT OR IGNORE first, or an import quietly takes the
  /// photographed pages with it.
  Future<int> importMagazines(List<Object?> entries) async {
    final db = await database;
    final batch = db.batch();
    var count = 0;
    for (final entry in entries) {
      if (entry is! Map<String, dynamic>) continue;
      batch.insert(
        magazinesTable,
        Magazine.fromJson(entry).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      count++;
    }
    await batch.commit(noResult: true);
    return count;
  }

  // Notes

  Future<List<Note>> getNotes() async {
    final db = await database;
    final rows = await db.query(notesTable, orderBy: 'date DESC');
    return rows.map(Note.fromMap).toList();
  }

  Future<void> addNote(Note note) async {
    final db = await database;
    await db.insert(
      notesTable,
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteNote(String id) async {
    final db = await database;
    await db.delete(notesTable, where: 'id = ?', whereArgs: [id]);
  }

  // Contents pages

  /// Every photographed page, oldest first.
  ///
  /// Ordered by when it was taken rather than by issue, because that is the
  /// order the pages of one issue were shot in: the contents spread, then the
  /// pattern sheets, which is the order they are bound in.
  Future<List<ContentsEntry>> getContents() async {
    final db = await database;
    final rows = await db.query(contentsTable, orderBy: 'addedOn');
    return rows.map(ContentsEntry.fromMap).toList();
  }

  Future<List<ContentsEntry>> getContentsFor(String magazineId) async {
    final db = await database;
    final rows = await db.query(
      contentsTable,
      where: 'magazineId = ?',
      whereArgs: [magazineId],
      orderBy: 'addedOn',
    );
    return rows.map(ContentsEntry.fromMap).toList();
  }

  Future<void> addContents(ContentsEntry entry) async {
    final db = await database;
    await db.insert(
      contentsTable,
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateContents(ContentsEntry entry) async {
    final db = await database;
    await db.update(
      contentsTable,
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> deleteContents(String id) async {
    final db = await database;
    await db.delete(contentsTable, where: 'id = ?', whereArgs: [id]);
  }

  /// Merges exported pages back in. Returns how many rows were written.
  Future<int> importContents(List<Object?> entries) async {
    final db = await database;
    final batch = db.batch();
    var count = 0;
    for (final entry in entries) {
      if (entry is! Map<String, dynamic>) continue;
      batch.insert(
        contentsTable,
        ContentsEntry.fromMap(entry).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      count++;
    }
    await batch.commit(noResult: true);
    return count;
  }

  /// Chronological order: by year, then by issue number within the year.
  static int compareByIssue(Magazine a, Magazine b) {
    final byYear = a.year.compareTo(b.year);
    return byYear != 0 ? byYear : a.issue.compareTo(b.issue);
  }
}
