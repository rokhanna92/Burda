import 'dart:convert';

import 'package:burda/models/note_provider.dart';
import 'package:burda/providers/magazine_provider.dart';
import 'package:burda/providers/theme_provider.dart';
import 'package:burda/screens/issue_screen.dart';
import 'package:burda/screens/vault_screen.dart';
import 'package:burda/screens/year_screen.dart';
import 'package:burda/services/database_service.dart';
import 'package:burda/shell/burda_nav.dart';
import 'package:burda/shell/burda_shell.dart';
import 'package:burda/theme/app_theme.dart';
import 'package:burda/theme/edition.dart';
import 'package:burda/widgets/cover_tile.dart';
import 'package:burda/widgets/hearts.dart';
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

/// 2011 runs to three issues, one of them held. 2013 holds a single issue,
/// unheld, so finishing 2011 finishes that volume rather than the whole
/// collection.
final _seed = [
  _issue(1, 2011, owned: true),
  _issue(2, 2011),
  _issue(3, 2011),
  _issue(1, 2013),
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
    await tester.pump(const Duration(milliseconds: 800));
  }

  Future<void> tapAsync(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await settle(tester);
  }

  Future<void> open(WidgetTester tester, BurdaPage page) async {
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
    BurdaNav.of(tester.element(find.byType(NavBar))).push(page);
    await settle(tester);
  }

  group('YearScreen', () {
    testWidgets('heads the volume with its tally', (tester) async {
      await open(tester, const YearPage(2011));

      expect(find.byType(YearScreen), findsOneWidget);
      expect(find.text('2011'), findsOneWidget);
      expect(find.text('1 of 3\nin the collection'), findsOneWidget);
    });

    testWidgets('lists every issue with its state', (tester) async {
      await open(tester, const YearPage(2011));

      expect(find.text('No. 1'), findsOneWidget);
      expect(find.text('No. 2'), findsOneWidget);
      expect(find.text('No. 3'), findsOneWidget);
      // Owned but unrated, against the two still to find.
      expect(find.text('unrated'), findsOneWidget);
      expect(find.text('missing'), findsNWidgets(2));
    });

    testWidgets('a full heart for what is held, an empty one for what is not', (
      tester,
    ) async {
      await open(tester, const YearPage(2011));

      expect(find.text('♥'), findsOneWidget);
      expect(find.text('♡'), findsNWidgets(2));
    });

    testWidgets('claims an issue from its heart', (tester) async {
      await open(tester, const YearPage(2011));

      await tapAsync(tester, find.text('♡').first);

      expect(magazines.byId('2-2011')!.isOwned, isTrue);
      expect(find.text('No. 2 / 2011 added'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2200));
    });

    testWidgets('finishing the volume rains hearts', (tester) async {
      await open(tester, const YearPage(2011));

      await tapAsync(tester, find.text('♡').first);
      await tapAsync(tester, find.text('♡').first);

      expect(find.text('Volume 2011 complete ♥'), findsOneWidget);
      expect(find.byType(Hearts), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 3000));
      await settle(tester);
    });

    testWidgets('opens an issue from its cover', (tester) async {
      await open(tester, const YearPage(2011));

      // The cover opens the issue; the caption under it is not a target.
      await tester.tap(find.byType(CoverTile).first);
      await settle(tester);

      expect(find.byType(IssueScreen), findsOneWidget);
      expect(find.text('Burda Style, 2011'), findsOneWidget);
    });

    testWidgets('offers to fill out a short year', (tester) async {
      await open(tester, const YearPage(2013));

      expect(find.text('Add the remaining issues of 2013'), findsOneWidget);

      await tapAsync(tester, find.text('Add the remaining issues of 2013'));

      expect(magazines.magazinesForYear(2013), hasLength(12));
      expect(find.text('11 issues filed under 2013'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2200));
    });

    testWidgets('a full year is not offered more issues', (tester) async {
      await open(tester, const YearPage(2013));
      await tapAsync(tester, find.text('Add the remaining issues of 2013'));
      await tester.pump(const Duration(milliseconds: 2200));

      expect(find.textContaining('Add the remaining'), findsNothing);
    });
  });

  group('VaultScreen', () {
    testWidgets('says what to do when it is empty', (tester) async {
      await open(tester, const VaultPage());

      expect(find.byType(VaultScreen), findsOneWidget);
      expect(find.text('0 photos'), findsOneWidget);
      expect(
        find.text(
          'Nothing here yet.\n'
          'Open an issue and add a photo of a pattern you sewed.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('lists each photo under the issue it came from', (
      tester,
    ) async {
      await tester.runAsync(
        () => magazines.addUploadedImage('1-2011', '/tmp/a.jpg'),
      );
      await tester.runAsync(
        () => magazines.addUploadedImage('1-2013', '/tmp/b.jpg'),
      );
      await open(tester, const VaultPage());

      expect(find.text('2 photos'), findsOneWidget);
      expect(find.text('No. 1 · 2011'), findsOneWidget);
      expect(find.text('No. 1 · 2013'), findsOneWidget);
    });

    testWidgets('taps through to the issue', (tester) async {
      await tester.runAsync(
        () => magazines.addUploadedImage('1-2011', '/tmp/a.jpg'),
      );
      await open(tester, const VaultPage());

      await tester.tap(find.text('No. 1 · 2011'));
      await settle(tester);

      expect(find.byType(IssueScreen), findsOneWidget);
      expect(find.text('Burda Style, 2011'), findsOneWidget);
    });
  });
}
