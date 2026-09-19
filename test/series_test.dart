import 'dart:convert';
import 'dart:io';

import 'package:burda/models/magazine.dart';
import 'package:burda/models/series.dart';
import 'package:burda/providers/magazine_provider.dart';
import 'package:burda/screens/collection_screen.dart';
import 'package:burda/screens/issue_screen.dart';
import 'package:burda/screens/year_screen.dart';
import 'package:burda/services/database_service.dart';
import 'package:burda/sheets/search_sheet.dart';
import 'package:burda/shell/burda_nav.dart';
import 'package:burda/shell/burda_shell.dart';
import 'package:burda/theme/app_theme.dart';
import 'package:burda/theme/edition.dart';
import 'package:burda/widgets/nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
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

final _seed = [_issue(1, 2019), _issue(2, 2019, owned: false)];

/// The version 2 schema, frozen: the version her phone is on.
const _v2Magazines = '''
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

const _v2Notes = '''
  CREATE TABLE notes (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    date TEXT NOT NULL
  )
''';

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

  Future<Magazine> file(
    Series series,
    int issue,
    int year, {
    bool owned = true,
  }) async {
    final id = Magazine.idFor(series: series, issue: issue, year: year);
    final magazine = Magazine(
      id: id,
      title: '$issue/$year',
      year: year,
      issue: issue,
      series: series,
      image: series.bundledCovers ? 'covers/$id.jpg' : '',
      isOwned: owned,
    );
    await magazines.addMagazine(magazine);
    return magazine;
  }

  group('a shelf', () {
    test('names an issue so two shelves cannot wear one name', () {
      expect(Series.style.markOf(4), 'No. 4');
      expect(Series.special.markOf(3), 'Special No. 3');
      expect(Series.easy.markOf(1), 'Easy No. 1');
    });

    test('knows whether it can be a fraction of itself', () {
      expect(Series.style.counted, isTrue);
      expect(Series.special.counted, isFalse);
    });

    test('is read back by name, and an unknown one is the main line', () {
      expect(Series.byId('special'), Series.special);
      expect(Series.byId('kaftans'), Series.style);
      expect(Series.byId(null), Series.style);
    });
  });

  group('an id', () {
    test('keeps the main line exactly as it always was', () {
      expect(
        Magazine.idFor(series: Series.style, issue: 4, year: 2019),
        '4-2019',
      );
    });

    test('prefixes every other shelf', () {
      expect(
        Magazine.idFor(series: Series.special, issue: 3, year: 2019),
        'special-3-2019',
      );
    });

    test('still gives up its issue number either way', () {
      expect(Magazine.issueFromId('4-2019'), 4);
      expect(Magazine.issueFromId('special-3-2019'), 3);
    });

    test('a row written before the column falls back to the id', () {
      final old = Magazine.fromMap({
        'id': '7-2019',
        'title': '7/2019',
        'year': 2019,
        'image': 'covers/7-2019.jpg',
      });

      expect(old.issue, 7);
      expect(old.series, Series.style);
      expect(old.mark, 'No. 7');
    });

    test('a shelved row reads its issue from the column', () {
      final filed = Magazine.fromMap({
        'id': 'special-3-2019',
        'title': '3/2019',
        'year': 2019,
        'image': '',
        'issue': 3,
        'series': 'special',
      });

      expect(filed.issue, 3);
      expect(filed.series, Series.special);
      expect(filed.mark, 'Special No. 3');
      expect(filed.hasCover, isFalse);
    });
  });

  group('the collection with more than one shelf', () {
    test('starts with one, and says so', () async {
      expect(magazines.manyShelves, isFalse);
      expect(magazines.startedShelves, hasLength(1));
      expect(magazines.startedShelves.single.series, Series.style);

      await file(Series.special, 3, 2019);

      expect(magazines.manyShelves, isTrue);
      expect(magazines.startedShelves, hasLength(2));
    });

    test('keeps the headline on the main line', () async {
      expect(magazines.headline.total, 2);
      expect(magazines.headline.owned, 1);

      await file(Series.special, 3, 2019);
      await file(Series.special, 4, 2019);

      expect(
        magazines.headline.total,
        2,
        reason: 'a shelf she fills by hand cannot move the percentage',
      );
      expect(magazines.mainLine.total, 2);
      expect(magazines.mainLine.missing, hasLength(1));
      // The library as a whole did grow, which is what the rank counts.
      expect(magazines.totalCount, 4);
      expect(magazines.ownedCount, 3);
    });

    test('an open shelf has no completion to report', () async {
      await file(Series.special, 3, 2019);

      final shelf = magazines.shelfFor(Series.special);
      expect(shelf.started, isTrue);
      expect(shelf.total, 1);
      expect(shelf.completion, isNull, reason: 'nobody can say how many');
      expect(magazines.shelfFor(Series.style).completion, 0.5);
    });

    test('keeps the years of one shelf out of another', () async {
      await file(Series.special, 3, 2021);

      expect(magazines.years, [2019], reason: 'the main line only');
      expect(magazines.shelfFor(Series.special).years, [2021]);
      expect(magazines.magazinesForYear(2019), hasLength(2));
      expect(
        magazines.magazinesForYear(2021, series: Series.special),
        hasLength(1),
      );
      expect(magazines.magazinesForYear(2021), isEmpty);
    });

    test('a year is complete on its own shelf, not across them', () async {
      await file(Series.special, 3, 2019);

      expect(magazines.isYearComplete(2019), isFalse, reason: '2/2019 is out');
      expect(magazines.isYearComplete(2019, series: Series.special), isTrue);
    });

    test('sorts by year, then shelf, then issue', () async {
      await file(Series.special, 1, 2019);

      expect(magazines.magazines.map((m) => m.id), [
        '1-2019',
        '2-2019',
        'special-1-2019',
      ]);
    });

    test('rides in the export and comes back on its own shelf', () async {
      await file(Series.special, 3, 2019);

      final exported = magazines.toExportJson();
      final shelved = exported.firstWhere((row) => row['series'] == 'special');
      expect(shelved['issue'], 3);
      expect(shelved['id'], 'special-3-2019');

      await magazines.import(exported);
      expect(magazines.shelfFor(Series.special).total, 1);
      expect(magazines.byId('special-3-2019')!.mark, 'Special No. 3');
    });
  });

  group('the ladder at rung 8', () {
    late Directory home;

    setUp(() async {
      home = await Directory.systemTemp.createTemp('burda-series');
    });

    tearDown(() async {
      if (home.existsSync()) await home.delete(recursive: true);
    });

    test('backfills the issue of every row written before it', () async {
      final path = p.join(home.path, 'burda.db');
      final old = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, version) async {
            await db.execute(_v2Magazines);
            await db.execute(_v2Notes);
            await db.execute(
              'CREATE INDEX idx_magazines_year ON magazines (year)',
            );
            await db.insert('magazines', {
              'id': '11-2019',
              'title': '11/2019',
              'year': 2019,
              'image': 'covers/11-2019.jpg',
              'isOwned': 1,
            });
          },
        ),
      );
      await old.close();

      final upgraded = DatabaseService(
        loadSeed: () async => jsonEncode(const []),
        databaseName: path,
      );
      addTearDown(upgraded.close);

      final kept = await upgraded.getMagazine('11-2019');
      expect(kept!.issue, 11, reason: 'read off the column, not the id');
      expect(kept.series, Series.style);
      expect(kept.isOwned, isTrue);
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

    testWidgets('draws no shelf heading while there is one shelf', (
      tester,
    ) async {
      await pumpApp(tester);
      BurdaNav.of(tester.element(find.byType(NavBar))).goTab(NavTab.collection);
      await settle(tester);

      expect(find.byType(CollectionScreen), findsOneWidget);
      expect(find.text('Burda Style'), findsNothing);
      expect(find.text('2019'), findsOneWidget, reason: 'the year group');
    });

    testWidgets('heads each shelf once there are two', (tester) async {
      await tester.runAsync(() => file(Series.special, 3, 2021));
      await pumpApp(tester);
      BurdaNav.of(tester.element(find.byType(NavBar))).goTab(NavTab.collection);
      await settle(tester);

      expect(find.text('Burda Style'), findsOneWidget);
      expect(find.text('Burda Style Special'), findsOneWidget);
    });

    testWidgets('an issue off the main line names its shelf', (tester) async {
      await tester.runAsync(() => file(Series.special, 3, 2021));
      await pumpApp(tester);
      BurdaNav.of(tester.element(find.byType(NavBar)))
          .push(const IssuePage('special-3-2021'));
      await settle(tester);

      expect(find.byType(IssueScreen), findsOneWidget);
      expect(find.text('Special No. 3'), findsOneWidget);
      expect(find.text('Burda Style Special, 2021'), findsOneWidget);
    });

    testWidgets('an open year counts rather than measures', (tester) async {
      await tester.runAsync(() async {
        await file(Series.special, 3, 2021);
        await file(Series.special, 4, 2021);
      });
      await pumpApp(tester);
      BurdaNav.of(tester.element(find.byType(NavBar)))
          .push(const YearPage(2021, series: Series.special));
      await settle(tester);

      expect(find.byType(YearScreen), findsOneWidget);
      expect(find.text('Burda Style Special'), findsOneWidget);
      expect(find.text('2 filed\nunder 2021'), findsOneWidget);
      // No fill button on a shelf nobody can count.
      expect(find.textContaining('Add the remaining issues'), findsNothing);
    });

    testWidgets('a counted year still measures', (tester) async {
      await pumpApp(tester);
      BurdaNav.of(tester.element(find.byType(NavBar)))
          .push(const YearPage(2019));
      await settle(tester);

      expect(find.text('1 of 2\nin the collection'), findsOneWidget);
    });

    testWidgets('the add sheet offers the shelves and files onto one', (
      tester,
    ) async {
      await pumpApp(tester);
      BurdaNav.of(tester.element(find.byType(NavBar)))
          .openSheet(BurdaSheet.add);
      await settle(tester);

      expect(find.text('Shelf'), findsOneWidget);
      expect(find.text('Special'), findsOneWidget);

      await tester.tap(find.text('Special'));
      await settle(tester);

      // The issue grid gives way to a stepper on an open shelf.
      expect(find.text('Whole year'), findsNothing);
      expect(find.textContaining('Add Special No. 1'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.textContaining('Add Special No. 1'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await settle(tester);

      expect(magazines.shelfFor(Series.special).total, 1);
      expect(
        find.textContaining('Special No. 1'),
        findsWidgets,
        reason: 'the toast says what it filed',
      );
    });

    testWidgets('one address finds it on every shelf', (tester) async {
      await tester.runAsync(() => file(Series.special, 1, 2019));
      await pumpApp(tester);
      BurdaNav.of(tester.element(find.byType(NavBar)))
          .openSheet(BurdaSheet.search);
      await settle(tester);

      await tester.enterText(find.byType(TextField).first, '1/2019');
      await settle(tester);

      // The index behind the sheet names the same issues in its rail, so
      // every assertion here is scoped to the sheet.
      Finder inSheet(String text) => find.descendant(
        of: find.byType(SearchSheet),
        matching: find.text(text),
      );

      expect(inSheet('No. 1 · 2019'), findsOneWidget);
      expect(inSheet('Special No. 1 · 2019'), findsOneWidget);
      expect(inSheet('Special, in the collection'), findsOneWidget);
    });
  });
}
