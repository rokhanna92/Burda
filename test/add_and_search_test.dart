import 'dart:convert';

import 'package:burda/models/note_provider.dart';
import 'package:burda/providers/magazine_provider.dart';
import 'package:burda/providers/theme_provider.dart';
import 'package:burda/screens/issue_screen.dart';
import 'package:burda/sheets/add_sheet.dart';
import 'package:burda/sheets/search_sheet.dart';
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

Map<String, Object?> _issue(int issue, int year, {bool owned = false}) => {
  'id': '$issue-$year',
  'title': '$issue/$year',
  'year': year,
  'image': 'covers/$issue-$year.jpg',
  'isOwned': owned,
};

/// 2024 is full, 2011 has one issue.
final _seed = [
  for (var issue = 1; issue <= 12; issue++) _issue(issue, 2024, owned: true),
  _issue(1, 2011, owned: true),
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

  Future<void> tapAsync(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await settle(tester);
  }

  /// Scoped to the sheet: the index sits behind it, and its covers and
  /// numbers would otherwise match the same finders.
  Finder inSheet(Type sheet, Finder matching) =>
      find.descendant(of: find.byType(sheet), matching: matching);

  Future<void> openSheet(WidgetTester tester, BurdaSheet sheet) async {
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
    BurdaNav.of(tester.element(find.byType(NavBar))).openSheet(sheet);
    await settle(tester);
  }

  group('AddSheet', () {
    testWidgets('offers twelve issue numbers and a year', (tester) async {
      await openSheet(tester, BurdaSheet.add);

      expect(find.text('Add an issue'), findsOneWidget);
      expect(find.text('Issue'), findsOneWidget);
      expect(find.text('Year'), findsOneWidget);
      expect(find.text('Choose a cover photo (optional)'), findsOneWidget);
      expect(find.text('Whole year'), findsOneWidget);
    });

    testWidgets('names the issue it is about to file', (tester) async {
      await openSheet(tester, BurdaSheet.add);
      final year = DateTime.now().year;

      expect(find.text('Add No. 1 / $year'), findsOneWidget);

      await tester.tap(inSheet(AddSheet, find.text('7')));
      await settle(tester);
      expect(find.text('Add No. 7 / $year'), findsOneWidget);
    });

    testWidgets('steps the year up and down', (tester) async {
      await openSheet(tester, BurdaSheet.add);
      final year = DateTime.now().year;

      await tester.tap(find.text('−'));
      await settle(tester);
      expect(find.text('${year - 1}'), findsOneWidget);

      await tester.tap(find.text('+'));
      await tester.pump();
      await tester.tap(find.text('+'));
      await settle(tester);
      // Never past next year.
      expect(find.text('${year + 1}'), findsOneWidget);
    });

    testWidgets('files an issue as held and says so', (tester) async {
      await openSheet(tester, BurdaSheet.add);
      final year = DateTime.now().year;

      await tester.tap(inSheet(AddSheet, find.text('3')));
      await settle(tester);
      await tapAsync(tester, find.text('Add No. 3 / $year'));

      final added = magazines.byId('3-$year');
      expect(added, isNotNull);
      expect(added!.isOwned, isTrue);
      expect(added.dateAdded, isNotNull);
      expect(
        find.text('No. 3 / $year added to the collection'),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 2200));
    });

    testWidgets('refuses an issue that is already filed', (tester) async {
      await openSheet(tester, BurdaSheet.add);

      // Step back to 2011, where issue 1 already exists.
      final year = DateTime.now().year;
      for (var step = 0; step < year - 2011; step++) {
        await tester.tap(find.text('−'));
        await tester.pump();
      }
      await settle(tester);

      await tapAsync(tester, find.text('Add No. 1 / 2011'));

      expect(find.text('That issue is already filed'), findsOneWidget);
      expect(magazines.magazinesForYear(2011), hasLength(1));

      await tester.pump(const Duration(milliseconds: 2200));
    });

    testWidgets('fills out a short year, unheld', (tester) async {
      await openSheet(tester, BurdaSheet.add);

      final year = DateTime.now().year;
      for (var step = 0; step < year - 2011; step++) {
        await tester.tap(find.text('−'));
        await tester.pump();
      }
      await settle(tester);

      await tapAsync(tester, find.text('Whole year'));

      expect(magazines.magazinesForYear(2011), hasLength(12));
      expect(magazines.ownedCountForYear(2011), 1);
      expect(find.text('2011 filed with 11 issues'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2200));
    });

    testWidgets('says when a year is already complete', (tester) async {
      await openSheet(tester, BurdaSheet.add);

      final year = DateTime.now().year;
      for (var step = 0; step < year - 2024; step++) {
        await tester.tap(find.text('−'));
        await tester.pump();
      }
      await settle(tester);

      await tapAsync(tester, find.text('Whole year'));

      expect(find.text('2024 is already complete'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2200));
    });
  });

  group('SearchSheet', () {
    testWidgets('asks for an address', (tester) async {
      await openSheet(tester, BurdaSheet.search);

      expect(find.text('Find an issue'), findsOneWidget);
      expect(find.text('the issue number, then the year'), findsOneWidget);
      // Nothing is claimed until an address is typed.
      expect(find.text('Nothing filed at that address yet.'), findsNothing);
    });

    testWidgets('waits for the whole year before looking', (tester) async {
      await openSheet(tester, BurdaSheet.search);

      await tester.enterText(find.byType(TextField), '2/20');
      await settle(tester);

      expect(find.text('Nothing filed at that address yet.'), findsNothing);
      expect(inSheet(SearchSheet, find.textContaining('No. ')), findsNothing);
    });

    testWidgets('puts the slash in so it need not be hunted for', (
      tester,
    ) async {
      await openSheet(tester, BurdaSheet.search);
      final field = find.byType(TextField);

      // Digits only, the way a thumb types them.
      await tester.enterText(field, '5');
      await settle(tester);
      expect(tester.widget<TextField>(field).controller!.text, '5');

      await tester.enterText(field, '52');
      await settle(tester);
      expect(tester.widget<TextField>(field).controller!.text, '5/2');

      await tester.enterText(field, '5/2024');
      await settle(tester);
      expect(find.text('No. 5 · 2024'), findsOneWidget);
    });

    testWidgets('waits on a 1, which could still be October or December', (
      tester,
    ) async {
      await openSheet(tester, BurdaSheet.search);
      final field = find.byType(TextField);
      String shown() => tester.widget<TextField>(field).controller!.text;

      await tester.enterText(field, '1');
      await settle(tester);
      expect(shown(), '1', reason: 'could still become 10, 11 or 12');

      await tester.enterText(field, '12');
      await settle(tester);
      expect(shown(), '12', reason: 'December, or issue 1 of a 2xxx year');

      // A 0 next means the year has begun, so the issue was 1.
      await tester.enterText(field, '120');
      await settle(tester);
      expect(shown(), '1/20');
    });

    testWidgets('reads December as December', (tester) async {
      await openSheet(tester, BurdaSheet.search);
      final field = find.byType(TextField);

      await tester.enterText(field, '122');
      await settle(tester);
      expect(tester.widget<TextField>(field).controller!.text, '12/2');

      await tester.enterText(field, '122024');
      await settle(tester);
      expect(find.text('No. 12 · 2024'), findsOneWidget);
    });

    testWidgets('finds an issue that is held', (tester) async {
      await openSheet(tester, BurdaSheet.search);

      await tester.enterText(find.byType(TextField), '5/2024');
      await settle(tester);

      expect(find.text('No. 5 · 2024'), findsOneWidget);
      expect(find.text('in the collection'), findsOneWidget);
    });

    testWidgets('says when nothing is filed there', (tester) async {
      await openSheet(tester, BurdaSheet.search);

      await tester.enterText(find.byType(TextField), '9/1999');
      await settle(tester);

      expect(find.text('Nothing filed at that address yet.'), findsOneWidget);
    });

    testWidgets('opens the issue it found', (tester) async {
      await openSheet(tester, BurdaSheet.search);

      await tester.enterText(find.byType(TextField), '5/2024');
      await settle(tester);
      await tester.tap(find.text('No. 5 · 2024'));
      await settle(tester);

      expect(find.byType(IssueScreen), findsOneWidget);
      expect(find.text('Burda Style, 2024'), findsOneWidget);
    });
  });
}
