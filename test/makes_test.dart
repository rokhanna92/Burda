import 'dart:convert';

import 'package:burda/models/garment_tag.dart';
import 'package:burda/models/make.dart';
import 'package:burda/providers/make_provider.dart';
import 'package:burda/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _seed = [
  {
    'id': '4-2019',
    'title': '4/2019',
    'year': 2019,
    'image': 'covers/4-2019.jpg',
    'isOwned': true,
  },
];

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService service;
  late MakeProvider makes;

  setUp(() async {
    service = DatabaseService(
      loadSeed: () async => jsonEncode(_seed),
      databaseName: inMemoryDatabasePath,
    );
    makes = MakeProvider(database: service);
    await makes.load();
  });

  tearDown(() => service.close());

  group('Make', () {
    test('names itself by the garment, then the pattern, then plainly', () {
      final base = Make(id: 'a', queuedOn: DateTime(2026));

      expect(base.copyWith(garment: GarmentTag.dress).name, 'Dress');
      expect(base.copyWith(patternNo: '118').name, 'Pattern 118');
      expect(base.name, 'A make');
    });

    test('writes the line beside its name, leaving out what is missing', () {
      final make = Make(
        id: 'a',
        queuedOn: DateTime(2026),
        patternNo: '118',
        size: '38',
      );

      expect(make.subtitle(null), 'pattern 118 · size 38');
      expect(Make(id: 'b', queuedOn: DateTime(2026)).subtitle(null), isEmpty);
    });

    test('is blank until something is written down', () {
      expect(Make(id: 'a', queuedOn: DateTime(2026)).isBlank, isTrue);
      expect(
        Make(id: 'a', queuedOn: DateTime(2026), fabric: 'linen').isBlank,
        isFalse,
      );
    });

    test('files itself under the last thing that happened to it', () {
      final queued = Make(id: 'a', queuedOn: DateTime(2026, 1));
      expect(queued.sortDate, DateTime(2026, 1));

      final started = queued.copyWith(startedOn: DateTime(2026, 2));
      expect(started.sortDate, DateTime(2026, 2));

      expect(
        started.copyWith(finishedOn: DateTime(2026, 3)).sortDate,
        DateTime(2026, 3),
      );
    });

    test('stamps the dates a move implies', () {
      final make = Make(id: 'a', queuedOn: DateTime(2026, 1));
      final now = DateTime(2026, 3, 9);

      final sewing = make.withStatus(MakeStatus.sewing, now: now);
      expect(sewing.startedOn, now);
      expect(sewing.finishedOn, isNull);

      final done = sewing.withStatus(MakeStatus.done, now: DateTime(2026, 4));
      // The start it already had is kept, not overwritten.
      expect(done.startedOn, now);
      expect(done.finishedOn, DateTime(2026, 4));
    });

    test('gives a make written up long after the fact a start as well', () {
      final make = Make(id: 'a', queuedOn: DateTime(2026, 1));
      final done = make.withStatus(MakeStatus.done, now: DateTime(2026, 4));

      expect(done.startedOn, DateTime(2026, 4));
      expect(done.finishedOn, DateTime(2026, 4));
    });

    test('dragging one back out of Done takes its dates off again', () {
      final done = Make(
        id: 'a',
        queuedOn: DateTime(2026, 1),
      ).withStatus(MakeStatus.done, now: DateTime(2026, 4));

      final back = done.withStatus(MakeStatus.queued);
      expect(back.startedOn, isNull);
      expect(back.finishedOn, isNull);

      // And out of Done but still on the table keeps the start.
      final sewing = done.withStatus(MakeStatus.sewing);
      expect(sewing.startedOn, DateTime(2026, 4));
      expect(sewing.finishedOn, isNull);
    });

    test('a row it cannot read is something she meant to make', () {
      expect(MakeStatus.parse('sewing'), MakeStatus.sewing);
      expect(MakeStatus.parse('Sewing'), MakeStatus.queued);
      expect(MakeStatus.parse(null), MakeStatus.queued);
    });

    test('survives a row with nothing but an id and a date', () {
      final make = Make.fromMap({
        'id': 'a',
        'queuedOn': '2026-03-09T10:00:00.000',
      });

      expect(make.patternNo, isEmpty);
      expect(make.garment, isNull);
      expect(make.status, MakeStatus.queued);
      expect(make.photos, isEmpty);
      expect(make.magazineId, isNull);
    });

    test('writes its photos encoded for the row and inline for the file', () {
      final make = Make(
        id: 'a',
        queuedOn: DateTime(2026),
        photos: const ['/tmp/a.jpg'],
      );

      expect(make.toMap()['photos'], '["/tmp/a.jpg"]');
      expect(make.toJson()['photos'], ['/tmp/a.jpg']);
      expect(Make.fromJson(make.toJson()).photos, ['/tmp/a.jpg']);
    });
  });

  group('the journal', () {
    test('a make written is a make read back', () async {
      final made = await makes.addMake(
        magazineId: '4-2019',
        patternNo: '118',
        garment: GarmentTag.dress,
        size: '38',
        fabric: 'charcoal linen',
        queuedOn: DateTime(2026, 3, 4),
      );

      final stored = await service.getMakes();
      expect(stored, hasLength(1));
      expect(stored.single.id, made.id);
      expect(stored.single.garment, GarmentTag.dress);
      expect(stored.single.fabric, 'charcoal linen');
      expect(stored.single.status, MakeStatus.queued);
    });

    test('sorts newest first, and re-sorts when one moves', () async {
      final older = await makes.addMake(
        patternNo: '1',
        queuedOn: DateTime(2026, 1),
      );
      final newer = await makes.addMake(
        patternNo: '2',
        queuedOn: DateTime(2026, 2),
      );

      expect(makes.makes.map((m) => m.id), [newer.id, older.id]);

      // Finishing the older one files it under today, so it moves to the top.
      await makes.setStatus(older.id, MakeStatus.done, now: DateTime(2026, 5));
      expect(makes.makes.map((m) => m.id), [older.id, newer.id]);
    });

    test('groups by what is on the go, waiting and made', () async {
      final a = await makes.addMake(patternNo: '1');
      final b = await makes.addMake(patternNo: '2');
      await makes.addMake(patternNo: '3');

      await makes.setStatus(a.id, MakeStatus.sewing);
      await makes.setStatus(b.id, MakeStatus.done);

      expect(makes.onTheGo.map((m) => m.patternNo), ['1']);
      expect(makes.made.map((m) => m.patternNo), ['2']);
      expect(makes.queued.map((m) => m.patternNo), ['3']);
      expect(makes.count, 3);
      expect(makes.finishedCount, 1);
      expect(makes.queuedCount, 1);
    });

    test('knows which makes came out of which issue', () async {
      await makes.addMake(magazineId: '4-2019', patternNo: '1');
      await makes.addMake(magazineId: '4-2019', patternNo: '2');
      await makes.addMake(patternNo: '3');

      expect(makes.forIssue('4-2019'), hasLength(2));
      expect(makes.madeCountFor('4-2019'), 2);
      expect(makes.madeCountFor('5-2019'), 0);
    });

    test('counts and lists its photos', () async {
      final make = await makes.addMake(patternNo: '118');
      await makes.addPhoto(make.id, '/tmp/a.jpg');
      await makes.addPhoto(make.id, '/tmp/b.jpg');
      // The same photo twice is still one photo.
      await makes.addPhoto(make.id, '/tmp/a.jpg');

      expect(makes.photoCount, 2);
      expect(makes.photos.map((p) => p.path), ['/tmp/a.jpg', '/tmp/b.jpg']);
      expect(makes.photos.first.make.id, make.id);

      await makes.removePhoto(make.id, '/tmp/a.jpg');
      expect(makes.photoCount, 1);
    });

    test('a make outlives the issue it came from', () async {
      final make = await makes.addMake(
        magazineId: '4-2019',
        garment: GarmentTag.coat,
      );
      await service.deleteMagazine('4-2019');

      // No cascade: the row is still there, holding a dangling id that
      // re-attaches by itself when the re-seed brings the issue back.
      await makes.load();
      expect(makes.byId(make.id), isNotNull);
      expect(makes.byId(make.id)!.magazineId, '4-2019');
    });

    test('an export of the journal reads straight back in', () async {
      final make = await makes.addMake(
        magazineId: '4-2019',
        patternNo: '118',
        garment: GarmentTag.dress,
      );
      await makes.setStatus(make.id, MakeStatus.done, now: DateTime(2026, 4));

      final exported = makes.toExportJson();
      await makes.deleteMake(make.id);
      expect(makes.count, 0);

      final written = await makes.import(exported);

      expect(written, 1);
      expect(makes.count, 1);
      expect(makes.made.single.garment, GarmentTag.dress);
      expect(makes.made.single.finishedOn, DateTime(2026, 4));
    });

    test('an import skips what is not an object', () async {
      final written = await makes.import([
        {'id': 'a', 'queuedOn': '2026-03-09T10:00:00.000', 'patternNo': '118'},
        'not a make',
      ]);

      expect(written, 1);
      expect(makes.count, 1);
    });
  });

  group('the ladder at rung 4', () {
    test('a fresh database has somewhere to put a make', () async {
      expect(await service.getMakes(), isEmpty);
      expect(DatabaseService.schemaVersion, greaterThanOrEqualTo(4));
    });
  });
}
