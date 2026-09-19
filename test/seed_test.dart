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

  // The bundled list stopped being a blank catalogue when her collection was
  // baked into it: it is her shelf as the original app had it on 19 September
  // 2026, so a fresh install is already hers rather than an empty one.
  group('the bundled issue list', () {
    late List<Magazine> issues;

    setUpAll(() {
      final raw = jsonDecode(File('assets/magazines.json').readAsStringSync());
      issues = [
        for (final entry in raw as List)
          Magazine.fromJson(entry as Map<String, dynamic>),
      ];
    });

    test('runs from 2002 to 2026', () {
      final years = issues.map((m) => m.year).toSet().toList()..sort();
      expect(years.first, 2002);
      expect(years.last, 2026);
      expect(years, hasLength(25));
    });

    test('gives every year she collected in full its twelve issues', () {
      for (var year = 2010; year <= 2025; year++) {
        expect(issues.where((m) => m.year == year).length, 12, reason: '$year');
      }
    });

    test('carries only what she has of the years before 2010', () {
      // The original app only ever recorded the issues she bought, so those
      // years are partial on purpose and nothing in them counts as missing.
      final back = issues.where((m) => m.year < 2010).toList();
      expect(back, hasLength(52));
      expect(back.every((m) => m.isOwned), isTrue);
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

    test('is her collection, not an empty one', () {
      expect(issues, hasLength(253));
      expect(issues.where((m) => m.isOwned), hasLength(247));
      expect(
        issues.where((m) => !m.isOwned).map((m) => m.id).toList()..sort(),
        ['10-2018', '11-2021', '2-2019', '4-2021', '5-2021', '9-2017'],
      );
    });

    test('carries the day she got each one, and the one she rated', () {
      expect(issues.every((m) => m.dateAdded != null), isTrue);
      expect(issues.where((m) => m.conditionScore != null).map((m) => m.id), [
        '4-2006',
      ]);
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

    test('an install at version 2 gains the contents table', () async {
      final service = DatabaseService(
        loadSeed: () async => jsonEncode([_entry(1, 2025)]),
        databaseName: path,
      );
      addTearDown(service.close);

      final pages = await service.getContents();

      expect(pages, isEmpty, reason: 'the table is there and empty');
      final kept = await service.getMagazine('1-2025');
      expect(kept!.isOwned, isTrue);
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

  // The one guard that a rung was never quietly edited after it shipped. Her
  // phone climbed the ladder; a fresh install replays it from nothing. If the
  // two ever disagree, a rung has been changed under a database that already
  // ran it, and only the phone that upgraded would ever show it.
  group('a fresh install and one that upgraded', () {
    late Directory home;

    /// The schema as version 2 left it, which is the version her phone is on:
    /// version 1's tables, its index, and a longer bundled list.
    Future<String> upgradedFromV2() async {
      final path = p.join(home.path, 'upgraded.db');
      final old = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, version) async {
            await db.execute(_v1Magazines);
            await db.execute(_v1Notes);
            await db.execute(
              'CREATE INDEX idx_magazines_year ON magazines (year)',
            );
          },
        ),
      );
      await old.close();
      return path;
    }

    setUp(() async {
      home = await Directory.systemTemp.createTemp('burda-ladder');
    });

    tearDown(() async {
      if (home.existsSync()) await home.delete(recursive: true);
    });

    test('hold the very same schema', () async {
      final fresh = DatabaseService(
        loadSeed: () async => jsonEncode([_entry(1, 2025)]),
        databaseName: p.join(home.path, 'fresh.db'),
      );
      final upgraded = DatabaseService(
        loadSeed: () async => jsonEncode([_entry(1, 2025)]),
        databaseName: await upgradedFromV2(),
      );
      addTearDown(fresh.close);
      addTearDown(upgraded.close);

      Future<Map<String, Object?>> shapeOf(DatabaseService service) async {
        final db = await service.database;
        final objects = await db.query(
          'sqlite_master',
          columns: ['type', 'name'],
          where: "name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'",
          orderBy: 'type, name',
        );
        final shape = <String, Object?>{};
        for (final object in objects) {
          final name = object['name'] as String;
          shape['${object['type']} $name'] = object['type'] == 'table'
              ? await db.rawQuery('PRAGMA table_info($name)')
              : true;
        }
        return shape;
      }

      final one = await shapeOf(fresh);
      final other = await shapeOf(upgraded);

      expect(one.keys, isNotEmpty);
      expect(one.keys, contains('table contents'));
      expect(one.keys, contains('index idx_magazines_year'));
      expect(other.keys.toList(), one.keys.toList());
      for (final key in one.keys) {
        expect(other[key], one[key], reason: key);
      }
    });
  });
}
