import 'dart:convert';

import 'package:burda/models/note_provider.dart';
import 'package:burda/providers/magazine_provider.dart';
import 'package:burda/providers/theme_provider.dart';
import 'package:burda/screens/collection_screen.dart';
import 'package:burda/screens/issue_screen.dart';
import 'package:burda/screens/year_screen.dart';
import 'package:burda/screens/years_screen.dart';
import 'package:burda/services/database_service.dart';
import 'package:burda/shell/burda_nav.dart';
import 'package:burda/shell/burda_shell.dart';
import 'package:burda/theme/app_theme.dart';
import 'package:burda/theme/edition.dart';
import 'package:burda/widgets/cover_tile.dart';
import 'package:burda/widgets/nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Map<String, Object?> _issue(int issue, int year, {bool owned = false}) => {
  'id': '$issue-$year',
  'title': '$issue/$year',
  'year': year,
  'image': 'covers/$issue-$year.jpg',
  'isOwned': owned,
};

/// 2010 complete, 2011 half, 2012 empty.
final _seed = [
  _issue(1, 2010, owned: true),
  _issue(2, 2010, owned: true),
  _issue(1, 2011, owned: true),
  _issue(2, 2011),
  _issue(1, 2012),
  _issue(2, 2012),
];

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late DatabaseService service;
  late MagazineProvider magazines;
  late NoteProvider notes;

  setUp(() async {
    service = DatabaseService(
      loadSeed: () async => jsonEncode(_seed),
      databaseName: inMemoryDatabasePath,
    );
    magazines = MagazineProvider(database: service);
    notes = NoteProvider(database: service);
    await magazines.load();
    await notes.load();
  });

  tearDown(() => service.close());

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
  }

  Future<void> openTab(WidgetTester tester, NavTab tab) async {
    tester.view.physicalSize = const Size(1206, 7200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: magazines),
          ChangeNotifierProvider.value(value: notes),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: MaterialApp(
          theme: buildAppTheme(Edition.rose),
          home: const BurdaShell(),
        ),
      ),
    );
    await settle(tester);
    BurdaNav.of(tester.element(find.byType(NavBar))).goTab(tab);
    await settle(tester);
  }

  group('CollectionScreen', () {
    testWidgets('opens on what is held, newest volume first', (tester) async {
      await openTab(tester, NavTab.collection);

      expect(find.byType(CollectionScreen), findsOneWidget);
      expect(find.text('Owned 3'), findsOneWidget);
      expect(find.text('Missing 3'), findsOneWidget);

      // 2012 has nothing owned, so it is not printed at all.
      expect(find.text('2010'), findsOneWidget);
      expect(find.text('2011'), findsOneWidget);
      expect(find.text('2012'), findsNothing);
    });

    testWidgets('switches to what is still out there', (tester) async {
      await openTab(tester, NavTab.collection);

      await tester.tap(find.text('Missing 3'));
      await settle(tester);

      // 2010 is complete, so nothing of it is missing.
      expect(find.text('2010'), findsNothing);
      expect(find.text('2011'), findsOneWidget);
      expect(find.text('2012'), findsOneWidget);
    });

    testWidgets('counts the issues in each volume', (tester) async {
      await openTab(tester, NavTab.collection);

      expect(find.text('2 issues'), findsOneWidget); // 2010
      expect(find.text('1 issues'), findsOneWidget); // 2011
    });

    testWidgets('opens an issue from its cover', (tester) async {
      await openTab(tester, NavTab.collection);

      await tester.tap(find.byType(CoverTile).first);
      await settle(tester);

      expect(find.byType(IssueScreen), findsOneWidget);
    });

    testWidgets('opens the volume from its year', (tester) async {
      await openTab(tester, NavTab.collection);

      await tester.tap(find.text('2011'));
      await settle(tester);

      expect(find.byType(YearScreen), findsOneWidget);
    });

    testWidgets('the index can ask for the missing side', (tester) async {
      await openTab(tester, NavTab.collection);

      BurdaNav.of(tester.element(find.byType(NavBar)))
          .showCollection(owned: false);
      await settle(tester);

      expect(find.text('2010'), findsNothing);
      expect(find.text('2012'), findsOneWidget);
    });
  });

  group('YearsScreen', () {
    testWidgets('stands every year on the shelf', (tester) async {
      await openTab(tester, NavTab.years);

      expect(find.byType(YearsScreen), findsOneWidget);
      expect(find.text('1 complete volumes'), findsOneWidget);
      for (final year in ['2010', '2011', '2012']) {
        expect(find.text(year), findsWidgets, reason: year);
      }
    });

    testWidgets('prints the owned count on each spine', (tester) async {
      await openTab(tester, NavTab.years);

      // 2010 has two, 2011 one, 2012 none.
      expect(find.text('2'), findsWidgets);
      expect(find.text('0'), findsWidgets);
    });

    testWidgets('lists what is still missing, year by year', (tester) async {
      await openTab(tester, NavTab.years);

      expect(find.text('Still missing'), findsOneWidget);
      expect(find.text('3 issues'), findsOneWidget);
      expect(find.text('1 missing'), findsOneWidget); // 2011
      expect(find.text('2 missing'), findsOneWidget); // 2012
    });

    testWidgets('a complete year is not listed as missing', (tester) async {
      await openTab(tester, NavTab.years);

      expect(find.textContaining('missing'), findsNWidgets(3));
    });

    testWidgets('opens a volume from its spine', (tester) async {
      await openTab(tester, NavTab.years);

      await tester.tap(find.text('2011').first);
      await settle(tester);

      expect(find.byType(YearScreen), findsOneWidget);
    });
  });
}
