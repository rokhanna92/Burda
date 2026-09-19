import 'dart:convert';
import 'dart:math';

import 'package:burda/models/garment_tag.dart';
import 'package:burda/providers/tonight_provider.dart';
import 'package:burda/screens/index_screen.dart';
import 'package:burda/screens/issue_screen.dart';
import 'package:burda/services/database_service.dart';
import 'package:burda/shell/burda_shell.dart';
import 'package:burda/theme/app_theme.dart';
import 'package:burda/theme/edition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app_providers.dart';

Map<String, Object?> _issue(int issue, int year, {bool owned = true}) => {
  'id': '$issue-$year',
  'title': '$issue/$year',
  'year': year,
  'image': 'covers/$issue-$year.jpg',
  'isOwned': owned,
};

/// Three held, one not.
final _seed = [
  _issue(4, 2019),
  _issue(5, 2019),
  _issue(6, 2019),
  _issue(7, 2019, owned: false),
];

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late DatabaseService service;

  DatabaseService open(List<Map<String, Object?>> seed) => DatabaseService(
    loadSeed: () async => jsonEncode(seed),
    databaseName: inMemoryDatabasePath,
  );

  setUp(() => service = open(_seed));
  tearDown(() => service.close());

  TonightProvider deck({int seed = 1, DatabaseService? on}) =>
      TonightProvider(database: on ?? service, random: Random(seed));

  group('the deck', () {
    test('deals one issue she owns', () async {
      final tonight = deck();
      await tonight.load(now: DateTime(2026, 9, 19, 20));

      expect(tonight.id, isNotNull);
      expect(
        tonight.id,
        isNot('7-2019'),
        reason: 'an issue she does not own is a taunt, not a pleasure',
      );
      expect(tonight.dealtOn, DateTime(2026, 9, 19));
      expect(tonight.dealtCount, 1);
    });

    test('keeps the same card all evening', () async {
      final tonight = deck();
      await tonight.load(now: DateTime(2026, 9, 19, 20));
      final dealt = tonight.id;

      await tonight.load(now: DateTime(2026, 9, 19, 23));
      expect(tonight.id, dealt);

      // And across a restart, because the deck is in the database.
      final reopened = deck();
      await reopened.load(now: DateTime(2026, 9, 19, 23, 30));
      expect(reopened.id, dealt);
    });

    test('the evening runs past midnight, to four', () async {
      final tonight = deck();
      await tonight.load(now: DateTime(2026, 9, 19, 23, 50));
      final dealt = tonight.id;

      // Half past midnight is still tonight: she sews late.
      await tonight.load(now: DateTime(2026, 9, 20, 0, 30));
      expect(tonight.id, dealt);

      // Breakfast is a new evening.
      await tonight.load(now: DateTime(2026, 9, 20, 9));
      expect(tonight.dealtOn, DateTime(2026, 9, 20));
    });

    test('shows every issue before it shows one twice', () async {
      final tonight = deck();
      await tonight.load(now: DateTime(2026, 9, 19, 20));

      final seen = {tonight.id};
      await tonight.another();
      seen.add(tonight.id);
      await tonight.another();
      seen.add(tonight.id);

      expect(seen, hasLength(3), reason: 'three owned issues, three cards');
      expect(tonight.dealtCount, 3);
    });

    test(
      'reshuffles once the pass is done, without repeating itself',
      () async {
        final tonight = deck();
        await tonight.load(now: DateTime(2026, 9, 19, 20));
        await tonight.another();
        await tonight.another();
        final last = tonight.id;

        await tonight.another();

        expect(tonight.dealtCount, 1, reason: 'a fresh pass');
        expect(
          tonight.id,
          isNot(last),
          reason: 'a reshuffle that hands back the same cover reads as broken',
        );
      },
    );

    test('another one is never the one she is looking at', () async {
      final tonight = deck();
      await tonight.load(now: DateTime(2026, 9, 19, 20));

      for (var turn = 0; turn < 6; turn++) {
        final before = tonight.id;
        await tonight.another();
        expect(tonight.id, isNot(before), reason: 'turn $turn');
      }
    });

    test('an issue given up drops out of the pass', () async {
      final tonight = deck();
      await tonight.load(now: DateTime(2026, 9, 19, 20));
      final dealt = tonight.id!;

      await service.toggleOwnership(dealt);
      await tonight.load(now: DateTime(2026, 9, 19, 21));

      expect(tonight.id, isNot(dealt), reason: 'it is not hers tonight');
    });

    test('an empty shelf deals nothing and keeps what it had', () async {
      final empty = open([_issue(4, 2019, owned: false)]);
      addTearDown(empty.close);

      final tonight = deck(on: empty);
      await tonight.load(now: DateTime(2026, 9, 19, 20));

      expect(tonight.id, isNull);
      expect(tonight.dealtCount, 0);
    });

    test('one issue owned is dealt again rather than nothing', () async {
      final single = open([_issue(4, 2019)]);
      addTearDown(single.close);

      final tonight = deck(on: single);
      await tonight.load(now: DateTime(2026, 9, 19, 20));
      expect(tonight.id, '4-2019');

      await tonight.another();
      expect(tonight.id, '4-2019');
    });

    test('the evening of a moment turns at four in the morning', () {
      expect(
        TonightProvider.eveningOf(DateTime(2026, 9, 20, 2)),
        DateTime(2026, 9, 19),
      );
      expect(
        TonightProvider.eveningOf(DateTime(2026, 9, 20, 5)),
        DateTime(2026, 9, 20),
      );
    });
  });

  group('the card on the index', () {
    late TestApp app;

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
    }

    Future<void> open(WidgetTester tester, {DateTime? now}) async {
      tester.view.physicalSize = const Size(1206, 9000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      // Loading the deck reads the database, which a widget test's fake zone
      // would otherwise freeze halfway through.
      await tester.runAsync(() async {
        app = TestApp(service, now: now ?? DateTime(2026, 9, 19, 20));
        await app.load();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: app.providers,
          child: MaterialApp(
            theme: buildAppTheme(Edition.rose),
            home: const BurdaShell(),
          ),
        ),
      );
      await settle(tester);
    }

    testWidgets('heads a card with a way to ask for another', (tester) async {
      await open(tester);

      expect(find.byType(IndexScreen), findsOneWidget);
      expect(find.text('Tonight'), findsOneWidget);
      expect(find.text('another →'), findsOneWidget);
      expect(
        find.text('An evening with nothing planned. Take this one down.'),
        findsOneWidget,
      );
      expect(
        find.text('No. ${app.tonight.id!.split('-').first}'),
        findsOneWidget,
      );
    });

    testWidgets('another one deals a different issue', (tester) async {
      await open(tester);
      final before = app.tonight.id;

      await tester.runAsync(() async {
        await tester.tap(find.text('another →'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await settle(tester);

      expect(app.tonight.id, isNot(before));
      expect(
        find.text('No. ${app.tonight.id!.split('-').first}'),
        findsOneWidget,
      );
    });

    testWidgets('the card opens its issue', (tester) async {
      await open(tester);

      await tester.tap(
        find.text('An evening with nothing planned. Take this one down.'),
      );
      await settle(tester);

      expect(find.byType(IssueScreen), findsOneWidget);
    });

    testWidgets('says something else when she has sewn from it', (
      tester,
    ) async {
      await open(tester);
      await tester.runAsync(
        () => app.makes.addMake(
          magazineId: app.tonight.id,
          garment: GarmentTag.dress,
        ),
      );
      await settle(tester);

      expect(find.text('You have sewn from this one before.'), findsOneWidget);
      expect(
        find.text('An evening with nothing planned. Take this one down.'),
        findsNothing,
      );
    });

    testWidgets('says so when there is nothing to deal', (tester) async {
      await service.close();
      service = open2();
      await open(tester);

      expect(
        find.text(
          'Nothing to deal yet. The first issue you claim turns up '
          'here.',
        ),
        findsOneWidget,
      );
      expect(find.text('another →'), findsNothing);
    });
  });
}

/// A shelf with nothing on it.
DatabaseService open2() => DatabaseService(
  loadSeed: () async => jsonEncode([_issue(4, 2019, owned: false)]),
  databaseName: inMemoryDatabasePath,
);
