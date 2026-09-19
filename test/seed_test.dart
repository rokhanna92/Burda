import 'dart:convert';
import 'dart:io';

import 'package:burda/models/magazine.dart';
import 'package:burda/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The version 1 schema, frozen. An install made by the first build has
/// exactly this, and the upgrade has to cope with it.
const _v1Magazines = '''
  CREATE TABLE magazines (
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

const _v1Notes = '''
  CREATE TABLE notes (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    date TEXT NOT NULL
  )
''';

Map<String, Object?> _entry(int issue, int year) => {
  'id': '$issue-$year',
  'title': '$issue/$year',
  'year': year,
  'image': 'covers/$issue-$year.jpg',
  'isOwned': false,
};

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the bundled issue list', () {
    late List<Magazine> issues;

    setUpAll(() {
      final raw = jsonDecode(File('assets/magazines.json').readAsStringSync());
      issues = [
        for (final entry in raw as List)
          Magazine.fromJson(entry as Map<String, dynamic>),
      ];
    });

    test('runs from 2010 to 2026', () {
      final years = issues.map((m) => m.year).toSet().toList()..sort();
      expect(years.first, 2010);
      expect(years.last, 2026);
      expect(years, hasLength(17));
    });

    test('gives every finished year twelve issues', () {
      for (var year = 2010; year <= 2025; year++) {
        expect(issues.where((m) => m.year == year).length, 12, reason: '$year');
      }
    });

    test('carries the nine issues of 2026 that are out', () {
      final published = issues.where((m) => m.year == 2026).toList();
      expect(published, hasLength(9));
      expect(published.map((m) => m.issue).toList()..sort(), [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
      ]);
    });

    test('starts with nothing owned', () {
      expect(issues.every((m) => !m.isOwned), isTrue);
      expect(issues, hasLength(201));
    });

    test('has no duplicates', () {
      expect(issues.map((m) => m.id).toSet(), hasLength(issues.length));
    });

    test('points every issue at its cover', () {
      for (final magazine in issues) {
        expect(
          magazine.image,
          'covers/${magazine.id}.jpg',
          reason: magazine.id,
        );
        // Not every one ships artwork; those fall back to the issue number.
        expect(magazine.hasFileCover, isFalse);
      }
    });
  });

  group('updating an install made by an earlier build', () {
    late Directory home;
    late String path;

    setUp(() async {
      home = await Directory.systemTemp.createTemp('burda-upgrade');
      path = p.join(home.path, 'burda.db');

      // The database as version 1 left it: the short 2025, one issue held,
      // rated, with a photo.
      final old = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute(_v1Magazines);
            await db.execute(_v1Notes);
            for (var issue = 1; issue <= 4; issue++) {
              await db.insert('magazines', {
                ..._entry(issue, 2025),
                'isOwned': issue == 1 ? 1 : 0,
                'conditionScore': issue == 1 ? 8 : null,
                'uploadedImages': issue == 1 ? '["/tmp/a.jpg"]' : '[]',
              });
            }
          },
        ),
      );
      await old.close();
    });

    tearDown(() async {
      if (home.existsSync()) await home.delete(recursive: true);
    });

    test('adds the issues that are new to the list', () async {
      final service = DatabaseService(
        loadSeed: () async => jsonEncode([
          for (var issue = 1; issue <= 12; issue++) _entry(issue, 2025),
          for (var issue = 1; issue <= 9; issue++) _entry(issue, 2026),
        ]),
        databaseName: path,
      );
      addTearDown(service.close);

      final all = await service.getAllMagazines();

      expect(all.where((m) => m.year == 2025), hasLength(12));
      expect(all.where((m) => m.year == 2026), hasLength(9));
    });

    test('leaves what was already there exactly as it was', () async {
      final service = DatabaseService(
        loadSeed: () async => jsonEncode([
          for (var issue = 1; issue <= 12; issue++) _entry(issue, 2025),
        ]),
        databaseName: path,
      );
      addTearDown(service.close);

      final kept = await service.getMagazine('1-2025');

      expect(kept, isNotNull);
      expect(kept!.isOwned, isTrue, reason: 'ownership survives the update');
      expect(kept.conditionScore, 8);
      expect(kept.uploadedImages, ['/tmp/a.jpg']);
    });

    test('does not duplicate an issue it already has', () async {
      final service = DatabaseService(
        loadSeed: () async => jsonEncode([
          for (var issue = 1; issue <= 12; issue++) _entry(issue, 2025),
        ]),
        databaseName: path,
      );
      addTearDown(service.close);

      final all = await service.getAllMagazines();

      expect(all.map((m) => m.id).toSet(), hasLength(all.length));
      expect(all.where((m) => m.id == '1-2025'), hasLength(1));
    });
  });
}
