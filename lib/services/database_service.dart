import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/contents_entry.dart';
import '../models/magazine.dart';
import '../models/make.dart';
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
  /// 3: the contents index. 4: makes and the sew queue. 5: the settings table.
  /// 6: a favourite mark and a score for what is inside. 7: lending.
  static const int schemaVersion = 7;

  static const String magazinesTable = 'magazines';
  static const String notesTable = 'notes';
  static const String contentsTable = 'contents';
  static const String makesTable = 'makes';
  static const String settingsTable = 'settings';

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
    4: [_createMakes],
    5: [_createSettings],
    6: [_addIsFavourite, _addContentScore],
    7: [_addLentTo, _addLentOn],
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

  // Rung 4, the sewing journal. The queue is a row of this with status
  // 'queued', not a table of its own: starting a make is then a status change
  // rather than a copy between tables, and everything written down while it
  // waited is still attached.
  //
  // magazineId is nullable and soft, like the one above: a garment she sewed
  // does not stop existing because the issue left the shelf.
  static const String _createMakes =
      '''
          CREATE TABLE $makesTable (
            id TEXT PRIMARY KEY,
            magazineId TEXT,
            patternNo TEXT NOT NULL DEFAULT '',
            garment TEXT NOT NULL DEFAULT '',
            size TEXT NOT NULL DEFAULT '',
            fabric TEXT NOT NULL DEFAULT '',
            status TEXT NOT NULL DEFAULT 'queued',
            notes TEXT NOT NULL DEFAULT '',
            photos TEXT NOT NULL DEFAULT '[]',
            queuedOn TEXT NOT NULL,
            startedOn TEXT,
            finishedOn TEXT
          )
        ''';

  // Rung 5, the settings table: the few small facts that belong to the
  // collection rather than to the device. Her measurements, the day the shelf
  // was completed, tonight's issue. Everything here rides in the export, which
  // is why it is a table and not shared_preferences.
  static const String _createSettings =
      '''
          CREATE TABLE $settingsTable (
            "key" TEXT PRIMARY KEY NOT NULL,
            value TEXT NOT NULL,
            updatedAt TEXT NOT NULL
          )
        ''';

  // Rung 6, rating what is inside. A flag needs a constant default because
  // SQLite cannot add a NOT NULL column without one; the score is nullable
  // exactly as conditionScore is, and null means not judged.
  static const String _addIsFavourite =
      'ALTER TABLE $magazinesTable '
      'ADD COLUMN isFavourite INTEGER NOT NULL DEFAULT 0';

  static const String _addContentScore =
      'ALTER TABLE $magazinesTable ADD COLUMN contentScore INTEGER';

  // Rung 7, lending. Both nullable with no default, because being on the shelf
  // is the absence of a loan rather than a value. No history table: she wants
  // to know what is out of the house tonight, not to audit 2019.
  static const String _addLentTo =
      'ALTER TABLE $magazinesTable ADD COLUMN lentTo TEXT';

  static const String _addLentOn =
      'ALTER TABLE $magazinesTable ADD COLUMN lentOn TEXT';

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
    // design does: the score describes a copy that is no longer held. Her
    // favourite mark and her score for what is inside stay, because those are
    // about what is printed, and printing does not change hands.
    final updated = owned
        ? magazine.copyWith(isOwned: true, dateAdded: now ?? DateTime.now())
        : magazine.copyWith(
            isOwned: false,
            clearDateAdded: true,
            clearConditionScore: true,
            // An issue she does not own cannot be out of a house it is not in.
            clearLoan: true,
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

  /// Records who has an issue and the day it went out.
  ///
  /// Both columns are written together. A name of nothing but spaces is not a
  /// loan, and an issue she does not own cannot go out of a house it is not in,
  /// so either is left alone rather than half recorded.
  Future<Magazine?> lendIssue(String id, String to, {DateTime? now}) async {
    final magazine = await getMagazine(id);
    if (magazine == null) return null;
    final name = to.trim();
    if (name.isEmpty || !magazine.isOwned) return magazine;
    final updated = magazine.copyWith(
      lentTo: name,
      lentOn: now ?? DateTime.now(),
    );
    await updateMagazine(updated);
    return updated;
  }

  /// Puts it back on the shelf, forgetting who had it.
  ///
  /// There is no history to keep. The question is what is out of the house
  /// tonight, and a returned magazine is not part of it.
  Future<Magazine?> returnIssue(String id) async {
    final magazine = await getMagazine(id);
    if (magazine == null) return null;
    final updated = magazine.copyWith(clearLoan: true);
    await updateMagazine(updated);
    return updated;
  }

  /// Stores a 1 to 10 judgment of what is printed inside.
  ///
  /// The same range as [setCondition] on purpose: the two numbers sit on one
  /// screen and have to be readable against each other. The issue screen writes
  /// even numbers, its instrument having five marks.
  Future<Magazine?> setContentScore(String id, int score) async {
    final magazine = await getMagazine(id);
    if (magazine == null) return null;
    final updated = magazine.copyWith(contentScore: score.clamp(1, 10));
    await updateMagazine(updated);
    return updated;
  }

  /// Puts her mark on an issue, or takes it off.
  Future<Magazine?> toggleFavourite(String id) async {
    final magazine = await getMagazine(id);
    if (magazine == null) return null;
    final updated = magazine.copyWith(isFavourite: !magazine.isFavourite);
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

  // Settings

  Future<Map<String, String>> getSettings() async {
    final db = await database;
    final rows = await db.query(settingsTable);
    return {
      for (final row in rows) row['key']! as String: row['value']! as String,
    };
  }

  Future<String?> getSetting(String key) async => (await getSettings())[key];

  Future<void> setSetting(String key, String value, {DateTime? now}) =>
      writeSettings({key: value}, now: now);

  Future<void> clearSetting(String key) => writeSettings({key: null});

  /// Writes several settings at once, deleting the ones handed a null.
  ///
  /// One batch rather than a call each, because a set of measurements is taken
  /// in one sitting: half of them landing and half not is worse than none of
  /// them landing, and it would leave a date stamped over numbers from last
  /// year.
  Future<void> writeSettings(
    Map<String, String?> values, {
    DateTime? now,
  }) async {
    final db = await database;
    final stamp = (now ?? DateTime.now()).toIso8601String();
    final batch = db.batch();
    for (final MapEntry(:key, :value) in values.entries) {
      if (value == null) {
        // Quoted, because the column is literally named "key".
        batch.delete(settingsTable, where: '"key" = ?', whereArgs: [key]);
      } else {
        batch.insert(settingsTable, {
          'key': key,
          'value': value,
          'updatedAt': stamp,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
    await batch.commit(noResult: true);
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

  // Makes

  /// The whole journal, newest first.
  Future<List<Make>> getMakes() async {
    final db = await database;
    final rows = await db.query(makesTable);
    final makes = rows.map(Make.fromMap).toList();
    makes.sort(compareByMade);
    return makes;
  }

  Future<void> addMake(Make make) async {
    final db = await database;
    await db.insert(
      makesTable,
      make.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateMake(Make make) async {
    final db = await database;
    await db.update(
      makesTable,
      make.toMap(),
      where: 'id = ?',
      whereArgs: [make.id],
    );
  }

  Future<void> deleteMake(String id) async {
    final db = await database;
    await db.delete(makesTable, where: 'id = ?', whereArgs: [id]);
  }

  /// Merges exported makes back in, keeping makes the file does not mention.
  Future<int> importMakes(List<Object?> entries) async {
    final db = await database;
    final batch = db.batch();
    var count = 0;
    for (final entry in entries) {
      if (entry is! Map<String, dynamic>) continue;
      batch.insert(
        makesTable,
        Make.fromJson(entry).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      count++;
    }
    await batch.commit(noResult: true);
    return count;
  }

  /// Merges exported notes back in.
  ///
  /// Notes have never been in the export file, and the journal is going into it
  /// now, so they go in together rather than one build later.
  Future<int> importNotes(List<Object?> entries) async {
    final db = await database;
    final batch = db.batch();
    var count = 0;
    for (final entry in entries) {
      if (entry is! Map<String, dynamic>) continue;
      batch.insert(
        notesTable,
        Note.fromMap(entry).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      count++;
    }
    await batch.commit(noResult: true);
    return count;
  }

  /// The journal reads backwards, like a diary: the last thing that happened
  /// to a make is what files it.
  static int compareByMade(Make a, Make b) => b.sortDate.compareTo(a.sortDate);

  /// Chronological order: by year, then by issue number within the year.
  static int compareByIssue(Magazine a, Magazine b) {
    final byYear = a.year.compareTo(b.year);
    return byYear != 0 ? byYear : a.issue.compareTo(b.issue);
  }
}
