import 'dart:convert';

import 'package:burda/models/magazine.dart';
import 'package:burda/models/series.dart';
import 'package:burda/providers/magazine_provider.dart';
import 'package:burda/screens/issue_screen.dart';
import 'package:burda/screens/month_screen.dart';
import 'package:burda/screens/index_screen.dart';
import 'package:burda/screens/months_screen.dart';
import 'package:burda/screens/years_screen.dart';
import 'package:burda/services/database_service.dart';
import 'package:burda/shell/burda_nav.dart';
import 'package:burda/shell/burda_shell.dart';
import 'package:burda/theme/app_theme.dart';
import 'package:burda/theme/edition.dart';
import 'package:burda/theme/season.dart';
import 'package:burda/widgets/cover_tile.dart';
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

/// Two years of Mays and Septembers, with one May missing.
final _seed = [
  _issue(5, 2019),
  _issue(9, 2019),
  _issue(5, 2020, owned: false),
  _issue(9, 2020),
];

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late DatabaseService service;
  late TestApp app;
  late MagazineProvider magazines;

  setUp(() async {
    service = DatabaseService(
      loadSeed: () async => jsonEncode(_seed),
      databaseName: inMemoryDatabasePath,
    );
    app = TestApp(service);
    await app.load();
    magazines = app.magazines;
  });

  tearDown(() => service.close());

  group('the seasons', () {
    test('put every month under its weather', () {
      expect(Season.ofMonth(5), Season.petals);
      expect(Season.ofMonth(7), Season.sun);
      expect(Season.ofMonth(10), Season.leaves);
      expect(Season.ofMonth(1), Season.snow);
      expect(Season.ofMonth(12), Season.snow);
    });

    test('run the calendar four ways, spring first', () {
      expect(Season.calendar, [
        Season.petals,
        Season.sun,
        Season.leaves,
        Season.snow,
      ]);
      expect(Season.petals.months, [3, 4, 5]);
      expect(Season.snow.months, [12, 1, 2]);
    });

    test('the indoor three belong to an édition, not to the year', () {
      expect(Season.dust.months, isEmpty);
      expect(Season.stars.months, isEmpty);
      expect(Season.embers.months, isEmpty);
      expect(Season.calendar, isNot(contains(Season.dust)));
    });

    test('name themselves for a heading', () {
      expect(Season.petals.label, 'Petals');
      expect(Season.snow.label, 'Snow');
    });
  });

  group('a month', () {
    test('gathers every year of itself, oldest first', () {
      final mays = magazines.magazinesForMonth(5);

      expect(mays.map((m) => m.year), [2019, 2020]);
      expect(magazines.ownedCountForMonth(5), 1);
      expect(magazines.completionForMonth(5), 0.5);
    });

    test('is empty when the magazine never printed one', () {
      expect(magazines.magazinesForMonth(3), isEmpty);
      expect(magazines.completionForMonth(3), 0);
    });

    test('leaves out a shelf that does not run twelve to a year', () async {
      await magazines.addMagazine(
        Magazine(
          id: Magazine.idFor(series: Series.special, issue: 5, year: 2021),
          title: '5/2021',
          year: 2021,
          issue: 5,
          series: Series.special,
          image: '',
          isOwned: true,
        ),
      );

      expect(magazines.magazinesForMonth(5).map((m) => m.year), [
        2019,
        2020,
      ], reason: "a Special's fifth issue is not May");
    });
  });

  group('the screens', () {
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
    }

    Future<void> pumpApp(WidgetTester tester) async {
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

    testWidgets('the years shelf points at the seasons', (tester) async {
      await pumpApp(tester);
      BurdaNav.of(tester.element(find.byType(NavBar))).goTab(NavTab.years);
      await settle(tester);

      expect(find.byType(YearsScreen), findsOneWidget);
      expect(find.text('Seasons'), findsOneWidget);
      expect(find.text('the same month, every year →'), findsOneWidget);

      await tester.tap(find.text('Seasons'));
      await settle(tester);
      expect(find.byType(MonthsScreen), findsOneWidget);
    });

    testWidgets('lists only the months the magazine printed', (tester) async {
      await pumpApp(tester);
      BurdaNav.of(tester.element(find.byType(NavBar))).push(const MonthsPage());
      await settle(tester);

      expect(find.text('tap a month'), findsOneWidget);
      expect(find.text('Petals'), findsOneWidget);
      expect(find.text('March, April, May'), findsOneWidget);
      expect(find.text('May'), findsOneWidget);
      expect(find.text('September'), findsOneWidget);
      // Nothing was ever filed in July, so summer is not printed at all.
      expect(find.text('Sun'), findsNothing);
      expect(find.text('1 of 2'), findsOneWidget, reason: 'one May of two');
    });

    testWidgets('a month opens every year of itself', (tester) async {
      await pumpApp(tester);
      BurdaNav.of(tester.element(find.byType(NavBar))).push(const MonthsPage());
      await settle(tester);

      await tester.tap(find.text('May'));
      await settle(tester);

      expect(find.byType(MonthScreen), findsOneWidget);
      expect(find.text('May'), findsOneWidget, reason: 'the masthead');
      expect(find.text('1 of 2\nin the collection'), findsOneWidget);
      // The year is the caption, since every cover here is No. 5.
      expect(find.text('2019'), findsOneWidget);
      expect(find.text('2020'), findsOneWidget);
    });

    testWidgets('a cover opens its issue', (tester) async {
      await pumpApp(tester);
      BurdaNav.of(tester.element(find.byType(NavBar))).push(const MonthPage(5));
      await settle(tester);

      await tester.tap(find.byType(CoverTile).first);
      await settle(tester);

      expect(find.byType(IssueScreen), findsOneWidget);
      expect(find.text('Burda Style, 2019'), findsOneWidget);
    });

    testWidgets('says nothing is filed when nothing is', (tester) async {
      await tester.runAsync(() async {
        for (final magazine in [...magazines.magazines]) {
          await magazines.deleteMagazine(magazine.id);
        }
      });
      await pumpApp(tester);
      BurdaNav.of(tester.element(find.byType(NavBar))).push(const MonthsPage());
      await settle(tester);

      expect(
        find.text(
          'Nothing filed yet.\n'
          'The months fill as the collection does.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the index carries this month, captioned by year', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1206, 9000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MultiProvider(
          providers: app.providers,
          child: MaterialApp(
            theme: buildAppTheme(Edition.rose),
            home: Scaffold(
              body: BurdaNavScope(
                nav: _StubNav(),
                child: SingleChildScrollView(
                  child: IndexScreenUnderTest(today: DateTime(2026, 9, 19)),
                ),
              ),
            ),
          ),
        ),
      );
      await settle(tester);

      expect(find.text('September'), findsOneWidget);
      expect(find.text('every year →'), findsOneWidget);
      // Both Septembers are owned and each is captioned by its year alone.
      // findsWidgets rather than one: tonight's card prints a year too, and
      // which one it deals is not this test's business.
      expect(find.text('2019'), findsWidgets);
      expect(find.text('2020'), findsWidgets);
    });
  });
}

/// The index, pumped on its own with a fixed date.
class IndexScreenUnderTest extends StatelessWidget {
  const IndexScreenUnderTest({super.key, required this.today});

  final DateTime today;

  @override
  Widget build(BuildContext context) =>
      IndexScreen(edition: Edition.rose, today: today);
}

/// Stands in for the shell when a screen is pumped on its own.
class _StubNav implements BurdaNav {
  @override
  void back() {}
  @override
  void celebrate(String message) {}
  @override
  void closeReader() {}
  @override
  void closeSheet() {}
  @override
  void goTab(NavTab tab) {}
  @override
  void openReader(String magazineId, {int startAt = 0}) {}
  @override
  void openSheet(BurdaSheet sheet) {}
  @override
  void push(BurdaPage page) {}
  @override
  void rain() {}
  @override
  void showCollection({required bool owned}) {}
  @override
  void showToast(String message) {}
}
