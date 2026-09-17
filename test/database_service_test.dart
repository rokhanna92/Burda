import 'dart:convert';

import 'package:burda/models/collector_rank.dart';
import 'package:burda/models/magazine.dart';
import 'package:burda/models/note.dart';
import 'package:burda/models/note_provider.dart';
import 'package:burda/providers/magazine_provider.dart';
import 'package:burda/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Three issues across two years, shaped like `assets/magazines.json`.
const _seed = [
  {
    'id': '1-2010',
    'title': '1/2010',
    'year': 2010,
    'image': 'covers/1-2010.jpg',
    'isOwned': false,
  },
  {
    'id': '2-2010',
    'title': '2/2010',
    'year': 2010,
    'image': 'covers/2-2010.jpg',
    'isOwned': false,
  },
  {
    'id': '1-2011',
    'title': '1/2011',
    'year': 2011,
    'image': 'covers/1-2011.jpg',
    'isOwned': false,
  },
];

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseService service;

  setUp(() {
    service = DatabaseService(
      loadSeed: () async => jsonEncode(_seed),
      databaseName: inMemoryDatabasePath,
    );
  });

  tearDown(() => service.close());

  group('seeding', () {
    test('a fresh database gets the bundled issue list', () async {
      final magazines = await service.getAllMagazines();

      expect(magazines, hasLength(3));
      expect(magazines.map((m) => m.id), ['1-2010', '2-2010', '1-2011']);
      expect(magazines.every((m) => !m.isOwned), isTrue);
      expect(magazines.first.dateAdded, isNull);
      expect(magazines.first.conditionScore, isNull);
      expect(magazines.first.uploadedImages, isEmpty);
    });

    test('issues come back ordered by year then issue number', () async {
      await service.addMagazine(
        const Magazine(
          id: '10-2010',
          title: '10/2010',
          year: 2010,
          image: 'covers/10-2010.jpg',
        ),
      );

      final magazines = await service.getAllMagazines();

      expect(magazines.map((m) => m.id), [
        '1-2010',
        '2-2010',
        '10-2010',
        '1-2011',
      ]);
    });

    test('a year query returns only that year', () async {
      final magazines = await service.getMagazinesByYear(2010);

      expect(magazines.map((m) => m.id), ['1-2010', '2-2010']);
    });
  });

  group('ownership', () {
    test('owning an issue stamps dateAdded', () async {
      final now = DateTime(2026, 9, 17, 12, 30);

      final updated = await service.toggleOwnership('1-2010', now: now);

      expect(updated!.isOwned, isTrue);
      expect(updated.dateAdded, now);
      expect((await service.getMagazine('1-2010'))!.dateAdded, now);
    });

    test('giving an issue up clears dateAdded', () async {
      await service.toggleOwnership('1-2010');

      final updated = await service.toggleOwnership('1-2010');

      expect(updated!.isOwned, isFalse);
      expect(updated.dateAdded, isNull);
    });

    test('an unknown id is a no-op', () async {
      expect(await service.toggleOwnership('9-1999'), isNull);
    });
  });

  group('condition', () {
    test('a score is stored as given', () async {
      final updated = await service.setCondition('1-2010', 7);

      expect(updated!.conditionScore, 7);
      expect(updated.conditionLabel, 'Good');
    });

    test('scores outside 1 to 10 are clamped', () async {
      expect((await service.setCondition('1-2010', 42))!.conditionScore, 10);
      expect((await service.setCondition('1-2010', 0))!.conditionScore, 1);
    });
  });

  group('uploaded images', () {
    test('paths survive a round trip through the JSON column', () async {
      await service.addUploadedImage('1-2010', '/photos/a.jpg');
      await service.addUploadedImage('1-2010', '/photos/b.jpg');

      expect((await service.getMagazine('1-2010'))!.uploadedImages, [
        '/photos/a.jpg',
        '/photos/b.jpg',
      ]);
    });

    test('the same path is not added twice', () async {
      await service.addUploadedImage('1-2010', '/photos/a.jpg');
      await service.addUploadedImage('1-2010', '/photos/a.jpg');

      expect((await service.getMagazine('1-2010'))!.uploadedImages, hasLength(1));
    });

    test('removing a path leaves the others', () async {
      await service.addUploadedImage('1-2010', '/photos/a.jpg');
      await service.addUploadedImage('1-2010', '/photos/b.jpg');

      final updated = await service.removeUploadedImage(
        '1-2010',
        '/photos/a.jpg',
      );

      expect(updated!.uploadedImages, ['/photos/b.jpg']);
    });
  });

  group('import', () {
    test('an exported collection overwrites matching issues', () async {
      final count = await service.importMagazines([
        {
          'id': '1-2010',
          'title': '1/2010',
          'year': 2010,
          'image': 'covers/1-2010.jpg',
          'isOwned': true,
          'dateAdded': '2025-04-01T10:00:00.000',
          'conditionScore': 9,
          'uploadedImages': ['/photos/a.jpg'],
        },
      ]);

      final imported = (await service.getMagazine('1-2010'))!;
      expect(count, 1);
      expect(imported.isOwned, isTrue);
      expect(imported.conditionScore, 9);
      expect(imported.uploadedImages, ['/photos/a.jpg']);
      expect(imported.dateAdded, DateTime.parse('2025-04-01T10:00:00.000'));
    });

    test('issues the export does not mention are kept', () async {
      await service.toggleOwnership('1-2011');

      await service.importMagazines([
        {
          'id': '1-2010',
          'title': '1/2010',
          'year': 2010,
          'image': 'covers/1-2010.jpg',
          'isOwned': true,
        },
      ]);

      expect((await service.getMagazine('1-2011'))!.isOwned, isTrue);
      expect(await service.getAllMagazines(), hasLength(3));
    });

    test('entries that are not objects are skipped', () async {
      expect(await service.importMagazines(['nonsense', 42, null]), 0);
    });

    test('an issue the export adds is created', () async {
      await service.importMagazines([
        {
          'id': '5-2030',
          'title': '5/2030',
          'year': 2030,
          'image': 'covers/5-2030.jpg',
          'isOwned': true,
        },
      ]);

      expect(await service.getMagazine('5-2030'), isNotNull);
    });
  });

  group('notes', () {
    test('notes come back newest first', () async {
      await service.addNote(
        Note(
          id: 'a',
          title: 'Older',
          content: 'x',
          date: DateTime(2026, 1, 1),
        ),
      );
      await service.addNote(
        Note(
          id: 'b',
          title: 'Newer',
          content: 'y',
          date: DateTime(2026, 6, 1),
        ),
      );

      expect((await service.getNotes()).map((n) => n.title), [
        'Newer',
        'Older',
      ]);
    });

    test('a note can be deleted', () async {
      await service.addNote(
        Note(id: 'a', title: 'T', content: 'C', date: DateTime(2026, 1, 1)),
      );

      await service.deleteNote('a');

      expect(await service.getNotes(), isEmpty);
    });
  });

  group('Magazine parsing', () {
    test('isOwned is read from both JSON bools and SQLite integers', () {
      expect(
        Magazine.fromJson({
          'id': '1-2010',
          'title': '1/2010',
          'year': 2010,
          'image': 'covers/1-2010.jpg',
          'isOwned': true,
        }).isOwned,
        isTrue,
      );
      expect(
        Magazine.fromMap({
          'id': '1-2010',
          'title': '1/2010',
          'year': 2010,
          'image': 'covers/1-2010.jpg',
          'isOwned': 1,
        }).isOwned,
        isTrue,
      );
    });

    test('uploadedImages is read from a JSON string or a list', () {
      const row = {
        'id': '1-2010',
        'title': '1/2010',
        'year': 2010,
        'image': 'covers/1-2010.jpg',
        'isOwned': 0,
      };

      expect(
        Magazine.fromMap({...row, 'uploadedImages': '["/a.jpg"]'})
            .uploadedImages,
        ['/a.jpg'],
      );
      expect(
        Magazine.fromJson({...row, 'uploadedImages': ['/a.jpg']})
            .uploadedImages,
        ['/a.jpg'],
      );
      expect(Magazine.fromMap({...row, 'uploadedImages': ''}).uploadedImages,
          isEmpty);
    });

    test('the issue number comes from the id', () {
      expect(
        const Magazine(
          id: '12-2024',
          title: '12/2024',
          year: 2024,
          image: 'covers/12-2024.jpg',
        ).issue,
        12,
      );
    });

    test('condition labels follow the original Worn, Good, Mint wording', () {
      Magazine scored(int? score) => Magazine(
        id: '1-2010',
        title: '1/2010',
        year: 2010,
        image: 'covers/1-2010.jpg',
        conditionScore: score,
      );

      expect(scored(null).conditionLabel, isNull);
      expect(scored(3).conditionLabel, 'Worn');
      expect(scored(7).conditionLabel, 'Good');
      expect(scored(10).conditionLabel, 'Mint');
    });
  });

  group('collector rank', () {
    test('each band maps to its rank', () {
      expect(CollectorRank.forOwnedCount(0).name, 'Threadling');
      expect(CollectorRank.forOwnedCount(9).name, 'Threadling');
      expect(CollectorRank.forOwnedCount(10).name, 'Stitch Starter');
      expect(CollectorRank.forOwnedCount(24).name, 'Stitch Starter');
      expect(CollectorRank.forOwnedCount(25).name, 'Fabric Fanatic');
      expect(CollectorRank.forOwnedCount(50).name, 'Sartorial Stylist');
      expect(CollectorRank.forOwnedCount(100).name, 'Design Diva');
      expect(CollectorRank.forOwnedCount(999).name, 'Design Diva');
    });
  });

  group('MagazineProvider stats', () {
    late MagazineProvider provider;

    setUp(() async {
      provider = MagazineProvider(database: service);
      await provider.load();
    });

    test('a fresh collection is all missing', () {
      expect(provider.totalCount, 3);
      expect(provider.ownedCount, 0);
      expect(provider.missingCount, 3);
      expect(provider.completion, 0);
      expect(provider.rank.name, 'Threadling');
      expect(provider.latestAddition, isNull);
      expect(provider.averageCondition, isNull);
      expect(provider.vaultCount, 0);
    });

    test('owning issues updates the counts and completion', () async {
      await provider.toggleOwnership('1-2010');

      expect(provider.ownedCount, 1);
      expect(provider.missingCount, 2);
      expect(provider.completion, closeTo(1 / 3, 0.0001));
      expect(provider.latestAddition, isNotNull);
    });

    test('years are listed oldest first with per-year counts', () async {
      await provider.toggleOwnership('1-2010');

      expect(provider.years, [2010, 2011]);
      expect(provider.ownedCountForYear(2010), 1);
      expect(provider.missingCountForYear(2010), 1);
      expect(provider.isYearComplete(2010), isFalse);
    });

    test('a year counts as complete once every issue is owned', () async {
      await provider.toggleOwnership('1-2011');

      expect(provider.isYearComplete(2011), isTrue);
    });

    test('average condition covers only rated owned issues', () async {
      await provider.toggleOwnership('1-2010');
      await provider.toggleOwnership('2-2010');
      await provider.setCondition('1-2010', 10);
      await provider.setCondition('2-2010', 6);

      expect(provider.averageCondition, 8);
    });

    test('the vault counts photos across every issue', () async {
      await provider.addUploadedImage('1-2010', '/a.jpg');
      await provider.addUploadedImage('1-2011', '/b.jpg');

      expect(provider.vaultCount, 2);
    });

    test('a deleted issue leaves the collection', () async {
      await provider.deleteMagazine('1-2010');

      expect(provider.totalCount, 2);
      expect(provider.byId('1-2010'), isNull);
    });
  });

  group('NoteProvider', () {
    test('a new note lands at the top of the list', () async {
      final provider = NoteProvider(database: service);
      await provider.load();

      await provider.addNote(title: 'First', content: 'one');
      await provider.addNote(title: 'Second', content: 'two');

      expect(provider.count, 2);
      expect(provider.notes.first.title, 'Second');
      expect(provider.notes.first.id, isNotEmpty);
    });

    test('a deleted note leaves the list', () async {
      final provider = NoteProvider(database: service);
      await provider.load();
      final note = await provider.addNote(title: 'T', content: 'C');

      await provider.deleteNote(note.id);

      expect(provider.notes, isEmpty);
    });
  });
}
