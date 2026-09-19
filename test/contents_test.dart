import 'dart:convert';

import 'package:burda/models/contents_entry.dart';
import 'package:burda/models/garment_tag.dart';
import 'package:burda/providers/contents_provider.dart';
import 'package:burda/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _seed = [
  {
    'id': '1-2010',
    'title': '1/2010',
    'year': 2010,
    'image': 'covers/1-2010.jpg',
    'isOwned': true,
  },
  {
    'id': '2-2010',
    'title': '2/2010',
    'year': 2010,
    'image': 'covers/2-2010.jpg',
    'isOwned': true,
  },
];

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService service;
  late ContentsProvider contents;

  setUp(() async {
    service = DatabaseService(
      loadSeed: () async => jsonEncode(_seed),
      databaseName: inMemoryDatabasePath,
    );
    contents = ContentsProvider(database: service);
    await contents.load();
  });

  tearDown(() => service.close());

  group('ContentsEntry', () {
    test('reads its tags back in the enum order, however they went in', () {
      final entry = ContentsEntry(
        id: 'a',
        magazineId: '1-2010',
        path: '/tmp/a.jpg',
        addedOn: DateTime(2026, 9, 19),
        tags: const {GarmentTag.coat, GarmentTag.dress},
      );

      expect(entry.tagNames, ['dress', 'coat']);
      expect(ContentsEntry.fromMap(entry.toMap()).tags, entry.tags);
    });

    test('takes a stored string or an already decoded list alike', () {
      expect(ContentsEntry.parseTags('["dress","coat"]'), {
        GarmentTag.dress,
        GarmentTag.coat,
      });
      expect(ContentsEntry.parseTags(['skirt']), {GarmentTag.skirt});
      expect(ContentsEntry.parseTags(''), isEmpty);
      expect(ContentsEntry.parseTags(null), isEmpty);
    });

    test('drops a word this build has not heard of and keeps the rest', () {
      final entry = ContentsEntry.fromMap({
        'id': 'a',
        'magazineId': '1-2010',
        'path': '/tmp/a.jpg',
        'tags': '["dress","kaftan"]',
        'addedOn': '2026-09-19T10:00:00.000',
      });

      expect(entry.tags, {GarmentTag.dress});
      expect(entry.path, '/tmp/a.jpg');
    });

    test('survives a page whose date will not parse', () {
      final entry = ContentsEntry.fromMap({
        'id': 'a',
        'magazineId': '1-2010',
        'path': '/tmp/a.jpg',
        'addedOn': 'the other day',
      });

      expect(entry.addedOn, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('writes its tags inline for the export, encoded for the row', () {
      final entry = ContentsEntry(
        id: 'a',
        magazineId: '1-2010',
        path: '/tmp/a.jpg',
        addedOn: DateTime(2026, 9, 19),
        tags: const {GarmentTag.dress},
      );

      expect(entry.toJson()['tags'], ['dress']);
      expect(entry.toMap()['tags'], '["dress"]');
    });
  });

  group('the contents table', () {
    test('a page written is a page read back', () async {
      final entry = await contents.addPage(
        magazineId: '1-2010',
        path: '/tmp/a.jpg',
        now: DateTime(2026, 9, 19),
      );

      final stored = await service.getContents();
      expect(stored, hasLength(1));
      expect(stored.single.id, entry.id);
      expect(stored.single.magazineId, '1-2010');
      expect(stored.single.path, '/tmp/a.jpg');
      expect(stored.single.addedOn, DateTime(2026, 9, 19));
    });

    test('an issue is given its own pages and nobody else s', () async {
      await contents.addPage(magazineId: '1-2010', path: '/tmp/a.jpg');
      await contents.addPage(magazineId: '1-2010', path: '/tmp/b.jpg');
      await contents.addPage(magazineId: '2-2010', path: '/tmp/c.jpg');

      expect(contents.forIssue('1-2010'), hasLength(2));
      expect(contents.countFor('2-2010'), 1);
      expect(contents.countFor('3-2010'), 0);
      expect(contents.count, 3);
    });

    test('toggleTag marks a word, then takes it away again', () async {
      final entry = await contents.addPage(
        magazineId: '1-2010',
        path: '/tmp/a.jpg',
      );

      await contents.toggleTag(entry.id, GarmentTag.dress);
      expect(contents.byId(entry.id)!.tags, {GarmentTag.dress});
      expect(contents.byId(entry.id)!.isTagged, isTrue);

      await contents.toggleTag(entry.id, GarmentTag.dress);
      expect(contents.byId(entry.id)!.tags, isEmpty);

      // And it went to the database, not only to the list in memory.
      final stored = await service.getContentsFor('1-2010');
      expect(stored.single.tags, isEmpty);
    });

    test(
      'counts issues rather than pages, and leaves empty words out',
      () async {
        final first = await contents.addPage(
          magazineId: '1-2010',
          path: '/tmp/a.jpg',
        );
        final second = await contents.addPage(
          magazineId: '1-2010',
          path: '/tmp/b.jpg',
        );
        final other = await contents.addPage(
          magazineId: '2-2010',
          path: '/tmp/c.jpg',
        );

        await contents.toggleTag(first.id, GarmentTag.dress);
        await contents.toggleTag(second.id, GarmentTag.dress);
        await contents.toggleTag(other.id, GarmentTag.coat);

        // Two dress pages, but one issue to go and look at.
        expect(contents.issueCountsByTag, {
          GarmentTag.dress: 1,
          GarmentTag.coat: 1,
        });
        expect(
          contents.issueCountsByTag.containsKey(GarmentTag.skirt),
          isFalse,
        );
        expect(contents.issuesTagged(GarmentTag.dress), {'1-2010'});
      },
    );

    test('removing an issue takes every page of it and no others', () async {
      await contents.addPage(magazineId: '1-2010', path: '/tmp/a.jpg');
      await contents.addPage(magazineId: '1-2010', path: '/tmp/b.jpg');
      await contents.addPage(magazineId: '2-2010', path: '/tmp/c.jpg');

      await contents.removeIssue('1-2010');

      expect(contents.forIssue('1-2010'), isEmpty);
      expect(contents.forIssue('2-2010'), hasLength(1));
      expect(await service.getContents(), hasLength(1));
    });

    test('removing one page leaves the others where they were', () async {
      final first = await contents.addPage(
        magazineId: '1-2010',
        path: '/tmp/a.jpg',
      );
      await contents.addPage(magazineId: '1-2010', path: '/tmp/b.jpg');

      await contents.removePage(first.id);

      expect(contents.forIssue('1-2010').map((e) => e.path), ['/tmp/b.jpg']);
    });

    test('an import skips what is not an object, as issues do', () async {
      final written = await contents.import([
        {
          'id': 'a',
          'magazineId': '1-2010',
          'path': '/tmp/a.jpg',
          'tags': ['dress'],
          'addedOn': '2026-09-19T10:00:00.000',
        },
        'not a page',
        42,
      ]);

      expect(written, 1);
      expect(contents.count, 1);
      expect(contents.entries.single.tags, {GarmentTag.dress});
    });

    test('an export of a page reads straight back in', () async {
      final entry = await contents.addPage(
        magazineId: '1-2010',
        path: '/tmp/a.jpg',
      );
      await contents.toggleTag(entry.id, GarmentTag.jacket);

      final exported = contents.toExportJson();
      await contents.removeIssue('1-2010');
      expect(contents.count, 0);

      await contents.import(exported);

      expect(contents.count, 1);
      expect(contents.entries.single.tags, {GarmentTag.jacket});
      expect(contents.entries.single.magazineId, '1-2010');
    });

    test(
      'a page whose photograph is gone keeps its row and its marks',
      () async {
        final entry = await contents.addPage(
          magazineId: '1-2010',
          path: '/tmp/a.jpg',
        );
        await contents.toggleTag(entry.id, GarmentTag.coat);

        await contents.applyRelink([(id: entry.id, path: null)]);

        expect(contents.count, 1);
        expect(contents.byId(entry.id)!.path, '');
        expect(contents.byId(entry.id)!.tags, {GarmentTag.coat});
      },
    );
  });

  group('GarmentTag', () {
    test('reads a word by name and refuses one it does not know', () {
      expect(GarmentTag.parse('dress'), GarmentTag.dress);
      expect(GarmentTag.parse('Dresses'), isNull);
      expect(GarmentTag.parse(null), isNull);
      expect(GarmentTag.parse(7), isNull);
    });

    test('prints a shelf of them and one of them', () {
      expect(GarmentTag.dress.label, 'Dresses');
      expect(GarmentTag.dress.one, 'Dress');
      expect(GarmentTag.values, hasLength(10));
    });
  });
}
