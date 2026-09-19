import 'dart:convert';

import 'package:burda/models/note_provider.dart';
import 'package:burda/providers/magazine_provider.dart';
import 'package:burda/providers/theme_provider.dart';
import 'package:burda/screens/collection_screen.dart';
import 'package:burda/screens/index_screen.dart';
import 'package:burda/screens/issue_screen.dart';
import 'package:burda/screens/notes_screen.dart';
import 'package:burda/screens/profile_screen.dart';
import 'package:burda/screens/vault_screen.dart';
import 'package:burda/screens/years_screen.dart';
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

Map<String, Object?> _issue(
  int issue,
  int year, {
  bool owned = false,
  String? added,
}) => {
  'id': '$issue-$year',
  'title': '$issue/$year',
  'year': year,
  'image': 'covers/$issue-$year.jpg',
  'isOwned': owned,
  'dateAdded': ?added,
};

/// Three of four held, 2010 complete.
final _seed = [
  _issue(1, 2010, owned: true, added: '2026-01-05T10:00:00.000'),
  _issue(2, 2010, owned: true, added: '2026-03-09T10:00:00.000'),
  _issue(1, 2011, owned: true, added: '2026-02-01T10:00:00.000'),
  _issue(2, 2011),
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

  Future<void> open(
    WidgetTester tester, {
    NavTab? tab,
    double width = 1206,
  }) async {
    tester.view.physicalSize = Size(width, 7200);
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
    if (tab != null) {
      BurdaNav.of(tester.element(find.byType(NavBar))).goTab(tab);
      await settle(tester);
    }
  }

  group('IndexScreen', () {
    testWidgets('prints the masthead and the date', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: magazines),
            ChangeNotifierProvider.value(value: notes),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ],
          child: MaterialApp(
            theme: buildAppTheme(Edition.rose),
            home: Scaffold(
              body: BurdaNavScope(
                nav: _StubNav(),
                child: SingleChildScrollView(
                  child: IndexScreen(
                    edition: Edition.rose,
                    today: DateTime(2026, 9, 19),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await settle(tester);

      expect(find.text("The collector's index"), findsOneWidget);
      expect(find.text('Burda Style'), findsOneWidget);
      expect(find.text('Édition Rosé · September 2026'), findsOneWidget);
    });

    testWidgets('leads with how far along the collection is', (tester) async {
      await open(tester);

      expect(find.text('75%'), findsOneWidget);
      expect(find.text('of the collection\n3 of 4 issues'), findsOneWidget);
    });

    testWidgets('lists the six ways in, numbered', (tester) async {
      await open(tester);

      expect(find.text('Contents'), findsOneWidget);
      expect(find.text('tap a line'), findsOneWidget);
      for (final no in ['01', '02', '03', '04', '05', '06']) {
        expect(find.text(no), findsOneWidget, reason: no);
      }
      expect(find.textContaining('Owned'), findsWidgets);
      expect(find.textContaining('Threadling'), findsWidgets);
    });

    testWidgets('owned and missing lines open the right side', (tester) async {
      await open(tester);

      await tester.tap(find.text('02'));
      await settle(tester);

      expect(find.byType(CollectionScreen), findsOneWidget);
      // The missing side: 2010 is complete so it is not printed.
      expect(find.text('2010'), findsNothing);
      expect(find.text('2011'), findsOneWidget);
    });

    testWidgets('years, notes and vault lines go where they say', (
      tester,
    ) async {
      await open(tester);

      Future<void> backToIndex() async {
        BurdaNav.of(tester.element(find.byType(NavBar))).goTab(NavTab.home);
        await settle(tester);
      }

      await tester.tap(find.text('03'));
      await settle(tester);
      expect(find.byType(YearsScreen), findsOneWidget);
      await backToIndex();

      await tester.tap(find.text('04'));
      await settle(tester);
      expect(find.byType(NotesScreen), findsOneWidget);
      await backToIndex();

      await tester.tap(find.text('05'));
      await settle(tester);
      expect(find.byType(VaultScreen), findsOneWidget);
    });

    testWidgets('the rank line raises the ladder', (tester) async {
      await open(tester);

      await tester.tap(find.text('06'));
      await settle(tester);

      expect(find.text('Collector rank'), findsOneWidget);
      expect(find.text('0–4 issues'), findsOneWidget);
    });

    testWidgets('the rail shows what was claimed most recently first', (
      tester,
    ) async {
      await open(tester);

      expect(find.text('Recently added'), findsOneWidget);
      // 2/2010 was claimed in March, after 1/2011 in February.
      expect(find.text('No. 2 · 2010'), findsOneWidget);
      expect(find.text('No. 1 · 2011'), findsOneWidget);
      expect(find.text('No. 2 · 2011'), findsNothing); // not held
    });

    testWidgets('a cover in the rail opens its issue', (tester) async {
      await open(tester);

      await tester.tap(find.text('No. 2 · 2010'));
      await settle(tester);

      expect(find.byType(IssueScreen), findsOneWidget);
    });

    testWidgets('gives a contents title the room the value leaves', (
      tester,
    ) async {
      // The design's `1fr auto`: a one or two digit count should leave the
      // title almost the whole row, not half of it.
      tester.view.physicalSize = const Size(1206, 7200);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await open(tester);

      // The title is rich text: a 28px name with a 15px italic sub inside it.
      final finder = find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('still to find'),
      );
      expect(finder, findsOneWidget);
      final title = tester.getSize(finder);
      // The row is 350px wide inside the gutters; half would be 148.
      expect(title.width, greaterThan(200));
    });

    testWidgets('offers the search line', (tester) async {
      await open(tester);

      expect(find.text('Find an issue, e.g. 2/2024'), findsOneWidget);
    });
  });

  group('ProfileScreen', () {
    testWidgets('heads the colophon with the rank', (tester) async {
      await open(tester, tab: NavTab.profile);

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('Colophon'), findsOneWidget);
      expect(find.text('Collector rank'), findsOneWidget);
      expect(find.text('Threadling'), findsOneWidget);
      expect(find.text('2 more to Tacking Along'), findsOneWidget);
    });

    testWidgets('prints the day and night éditions', (tester) async {
      // Wide enough that the whole row is built, rather than the first few.
      await open(tester, tab: NavTab.profile, width: 3600);

      expect(find.text('Day'), findsOneWidget);
      expect(find.text('Night'), findsOneWidget);
      for (final edition in Edition.all) {
        expect(find.text(edition.name), findsWidgets, reason: edition.id);
      }
    });

    testWidgets('changing édition repaints the app and says so', (
      tester,
    ) async {
      await open(tester, tab: NavTab.profile, width: 3600);

      await tester.tap(find.text('Hiver'));
      await settle(tester);

      final theme = Provider.of<ThemeProvider>(
        tester.element(find.byType(NavBar)),
        listen: false,
      );
      expect(theme.edition, Edition.hiver);
      expect(find.text('Printed in the Hiver edition'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2200));
    });

    testWidgets('lists the archive and the promise under it', (tester) async {
      await open(tester, tab: NavTab.profile);

      expect(find.textContaining('Export collection'), findsOneWidget);
      expect(find.textContaining('Import collection'), findsOneWidget);
      expect(find.textContaining('About Burda Style'), findsOneWidget);
      expect(
        find.text(
          'Everything lives on this phone. '
          'Nothing leaves it unless you export.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('about opens the sheet', (tester) async {
      await open(tester, tab: NavTab.profile);

      await tester.tap(find.textContaining('About Burda Style'));
      await settle(tester);

      expect(find.text('Version 2.0'), findsOneWidget);
    });
  });
}

/// Stands in for the shell when a screen is pumped on its own.
class _StubNav implements BurdaNav {
  @override
  void back() {}
  @override
  void celebrate(String message) {}
  @override
  void closeSheet() {}
  @override
  void goTab(NavTab tab) {}
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
