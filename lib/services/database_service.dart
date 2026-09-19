import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/magazine.dart';
import '../models/note.dart';

/// Owns the SQLite store: the seeded `magazines` table and the `notes` table.
///
/// The original app kept these in two database files and carried five
/// migrations. A rebuilt install can never see those old files (it is a
/// different application id, signed with a different key), so this ships one
/// database at version 1 with the final schema. Existing collections come in
/// through [importMagazines] instead.
class DatabaseService {
  DatabaseService({
    Future<String> Function()? loadSeed,
    String databaseName = 'burda.db',
  }) : _loadSeed = loadSeed ?? _loadSeedFromAssets,
       // ignore: prefer_initializing_formals
       _databaseName = databaseName;

  static final DatabaseService instance = DatabaseService();

  /// Bumped whenever the bundled issue list grows.
  ///
  /// 1: the first build. 2: 2025 filled out to twelve issues and 2026 began.
  static const int schemaVersion = 2;
  static const String magazinesTable = 'magazines';
  static const String notesTable = 'notes';

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
      onCreate: (db, version) async {
        await db.execute('''
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
        ''');
        await db.execute('''
          CREATE TABLE $notesTable (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            date TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_magazines_year ON $magazinesTable (year)',
        );
        await _seed(db);
      },
      // The magazine keeps publishing, so the bundled list keeps growing. A
      // re-seed inserts what is new and, because it ignores conflicts, leaves
      // every row already there untouched: ownership, condition and photos all
      // survive.
      //
      // An issue deleted by hand does come back at this point. That is the
      // trade for ever seeing a new one, and it only happens on an update that
      // extends the list.
      onUpgrade: (db, from, to) async => _seed(db),
    );
  }

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
    final updated = owned
        ? magazine.copyWith(isOwned: true, dateAdded: now ?? DateTime.now())
        : magazine.copyWith(isOwned: false, clearDateAdded: true);
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

  /// Chronological order: by year, then by issue number within the year.
  static int compareByIssue(Magazine a, Magazine b) {
    final byYear = a.year.compareTo(b.year);
    return byYear != 0 ? byYear : a.issue.compareTo(b.issue);
  }
}
