import 'dart:convert';

import 'package:burda/models/collector_rank.dart';
import 'package:burda/models/endgame.dart';
import 'package:burda/providers/magazine_provider.dart';
import 'package:burda/screens/index_screen.dart';
import 'package:burda/screens/issue_screen.dart';
import 'package:burda/screens/profile_screen.dart';
import 'package:burda/services/database_service.dart';
import 'package:burda/shell/burda_nav.dart';
import 'package:burda/shell/burda_shell.dart';
import 'package:burda/theme/app_theme.dart';
import 'package:burda/theme/edition.dart';
import 'package:burda/widgets/nav_bar.dart';
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

/// Six issues over two years, with the last two still out there.
List<Map<String, Object?>> _shelf({int missing = 2}) => [
  for (var issue = 1; issue <= 3; issue++) _issue(issue, 2019),
  for (var issue = 1; issue <= 3; issue++)
    _issue(issue, 2020, owned: issue > missing),
];

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late DatabaseService service;
  late TestApp app;
  late MagazineProvider magazines;

  Future<void> start(List<Map<String, Object?>> seed) async {
    service = DatabaseService(
      loadSeed: () async => jsonEncode(seed),
      databaseName: inMemoryDatabasePath,
    );
    app = TestApp(service);
    await app.load();
    magazines = app.magazines;
  }

  setUp(() => start(_shelf()));
  tearDown(() => service.close());

  group('where the collection stands', () {
    test('a lot left is a percentage, not a list', () {
      final many = magazines.magazines.take(4).toList();

      expect(
        Endgame.of(total: 201, missing: many, completedOn: null),
        isA<Climbing>(),
      );
      expect(
        Endgame.of(
          total: 201,
          missing: many.take(3).toList(),
          completedOn: null,
        ),
        isA<LastFew>(),
      );
      expect(
        Endgame.of(total: 201, missing: const [], completedOn: null),
        isA<Finished>(),
      );
    });

    test('a handful left can be named', () async {
      expect(magazines.endgame, isA<LastFew>());
      expect((magazines.endgame as LastFew).issues, hasLength(2));
    });

    test('four left is a list, not a card', () async {
      await service.close();
      await start(_shelf(missing: 3));
      // Three is still nameable; a fourth tips it back to a percentage.
      expect(magazines.endgame, isA<LastFew>());

      await magazines.toggleOwnership('1-2019');
      expect(magazines.endgame, isA<Climbing>());
    });

    test('an empty shelf is not a finished one', () async {
      await service.close();
      await start([]);

      expect(magazines.endgame, isA<Climbing>());
      expect(magazines.completedOn, isNull);
    });

    test('the last issue finishes it and stamps the day', () async {
      await magazines.toggleOwnership('1-2020');
      expect(magazines.endgame, isA<LastFew>());

      await magazines.toggleOwnership('2-2020');

      expect(magazines.endgame, isA<Finished>());
      final first = await magazines.markComplete(now: DateTime(2026, 9, 19));
      expect(first, isTrue);
      expect(magazines.completedOn, DateTime(2026, 9, 19));
    });

    test('the date is written once and never moves', () async {
      await magazines.toggleOwnership('1-2020');
      await magazines.toggleOwnership('2-2020');
      await magazines.markComplete(now: DateTime(2026, 9, 19));

      // Falling under and coming back does not reset it.
      await magazines.toggleOwnership('1-2020');
      expect(magazines.endgame, isA<LastFew>());
      expect(magazines.completedOn, DateTime(2026, 9, 19));

      await magazines.toggleOwnership('1-2020');
      final again = await magazines.markComplete(now: DateTime(2027, 1, 1));
      expect(again, isFalse, reason: 'it is when it was done');
      expect(magazines.completedOn, DateTime(2026, 9, 19));
    });

    test('a collection that arrives finished is stamped on load', () async {
      await service.close();
      await start([_issue(1, 2019), _issue(2, 2019)]);

      expect(magazines.endgame, isA<Finished>());
      expect(magazines.completedOn, isNotNull);

      // And it survives a restart, because it is a settings row.
      final fresh = MagazineProvider(database: service);
      await fresh.load();
      expect(fresh.completedOn, magazines.completedOn);
    });

    test('the main line knows its own span', () async {
      expect(magazines.mainLine.total, 6);
      expect(magazines.mainLine.owned, 4);
      expect(magazines.mainLine.years, [2019, 2020]);
      expect(magazines.mainLine.missing, hasLength(2));
    });
  });

  group('the ladder at the top', () {
    test('still points somewhere below the top rung', () {
      expect(CollectorRank.hintFor(0), '5 more to Tacking Along');
      expect(CollectorRank.hintFor(0, remaining: 3), '5 more to Tacking Along');
    });

    test('says what is left of the shelf at the top', () {
      expect(CollectorRank.hintFor(199), 'the top of the ladder');
      expect(
        CollectorRank.hintFor(199, remaining: 2),
        'the top of the ladder, 2 issues to go',
      );
      expect(
        CollectorRank.hintFor(200, remaining: 1),
        'the top of the ladder, one issue to go',
      );
      expect(
        CollectorRank.hintFor(201, remaining: 0),
        'the top of the ladder, and the whole shelf',
      );
    });
  });

  group('the index', () {
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
    }

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1206, 9000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

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

    testWidgets('names the last two and routes to each', (tester) async {
      await open(tester);

      expect(find.byType(IndexScreen), findsOneWidget);
      expect(find.text('The last two'), findsOneWidget);
      expect(find.text('then it is finished'), findsOneWidget);
      expect(find.textContaining('No. 1 / 2020'), findsOneWidget);
      expect(find.textContaining('January'), findsOneWidget);

      await tester.tap(find.textContaining('No. 1 / 2020'));
      await settle(tester);
      expect(find.byType(IssueScreen), findsOneWidget);
    });

    testWidgets('leads with the archive once it is finished', (tester) async {
      await tester.runAsync(() async {
        await magazines.toggleOwnership('1-2020');
        await magazines.toggleOwnership('2-2020');
        await magazines.markComplete(now: DateTime(2026, 9, 19));
      });
      await open(tester);

      expect(find.text('6'), findsWidgets, reason: 'the size of the archive');
      expect(find.text('the complete run\n2019 to 2020'), findsOneWidget);
      expect(find.text('Completed 19 September 2026'), findsOneWidget);
      expect(find.text('100%'), findsNothing);
      expect(find.text('The last two'), findsNothing);
    });

    testWidgets('goes back under without looking broken', (tester) async {
      await tester.runAsync(() async {
        await magazines.toggleOwnership('1-2020');
        await magazines.toggleOwnership('2-2020');
        await magazines.markComplete(now: DateTime(2026, 9, 19));
      });
      await open(tester);
      expect(find.text('Completed 19 September 2026'), findsOneWidget);

      await tester.runAsync(() => magazines.toggleOwnership('1-2020'));
      await settle(tester);

      expect(find.text('Completed 19 September 2026'), findsNothing);
      expect(find.text('The last issue'), findsOneWidget);
      expect(find.text('83%'), findsOneWidget);
    });

    testWidgets('the rank line says how much shelf is left', (tester) async {
      await open(tester);

      expect(
        find.textContaining('the top of the ladder'),
        findsNothing,
        reason: 'four issues is nowhere near the top rung',
      );
      expect(find.textContaining('more to'), findsWidgets);
    });
  });

  group('the colophon', () {
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
    }

    Future<void> openProfile(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1206, 9000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

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
      BurdaNav.of(tester.element(find.byType(NavBar))).goTab(NavTab.profile);
      await settle(tester);
    }

    testWidgets('has no card while there is anything left', (tester) async {
      await openProfile(tester);

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('The collection'), findsNothing);
    });

    testWidgets('records it once it is done', (tester) async {
      await tester.runAsync(() async {
        await magazines.toggleOwnership('1-2020');
        await magazines.toggleOwnership('2-2020');
        await magazines.markComplete(now: DateTime(2026, 9, 19));
      });
      await openProfile(tester);

      expect(find.text('The collection'), findsOneWidget);
      expect(find.text('Complete'), findsOneWidget);
      expect(find.text('6 issues, 2019 to 2020'), findsOneWidget);
      expect(find.text('Finished 19 September 2026'), findsOneWidget);
    });
  });
}
