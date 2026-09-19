import 'dart:convert';

import 'package:burda/models/note_provider.dart';
import 'package:burda/providers/magazine_provider.dart';
import 'package:burda/providers/theme_provider.dart';
import 'package:burda/screens/index_screen.dart';
import 'package:burda/screens/issue_screen.dart';
import 'package:burda/services/database_service.dart';
import 'package:burda/shell/burda_nav.dart';
import 'package:burda/shell/burda_shell.dart';
import 'package:burda/theme/app_theme.dart';
import 'package:burda/theme/edition.dart';
import 'package:burda/widgets/hearts.dart';
import 'package:burda/widgets/nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Two issues in one year, so finishing the second finishes the volume.
const _seed = [
  {
    'id': '1-2011',
    'title': '1/2011',
    'year': 2011,
    'image': 'covers/1-2011.jpg',
    'isOwned': true,
  },
  {
    'id': '2-2011',
    'title': '2/2011',
    'year': 2011,
    'image': 'covers/2-2011.jpg',
    'isOwned': false,
  },
  {
    'id': '3-2012',
    'title': '3/2012',
    'year': 2012,
    'image': 'covers/3-2012.jpg',
    'isOwned': false,
  },
  // A second issue in 2012, so adding the first does not finish the volume.
  {
    'id': '4-2012',
    'title': '4/2012',
    'year': 2012,
    'image': 'covers/4-2012.jpg',
    'isOwned': false,
  },
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
    await tester.pump(const Duration(milliseconds: 700));
  }

  /// Taps in the real async zone, then settles.
  ///
  /// A widget test's fake zone freezes real I/O, and these controls write to
  /// the database twice over: read the row, then update it. Driving the whole
  /// gesture through runAsync lets both round trips finish.
  Future<void> tapAsync(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settle(tester);
  }

  Future<void> openIssue(WidgetTester tester, String id) async {
    // The design's width, but tall enough that the whole screen is on show:
    // scrolling a control into view before tapping it is a variable this test
    // does not need.
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
    BurdaNav.of(tester.element(find.byType(NavBar))).push(IssuePage(id));
    await settle(tester);
  }

  testWidgets('names the issue and the magazine', (tester) async {
    await openIssue(tester, '2-2011');

    expect(find.byType(IssueScreen), findsOneWidget);
    expect(find.text('No. 2'), findsOneWidget);
    expect(find.text('Burda Style, 2011'), findsOneWidget);
  });

  testWidgets('offers to add an issue that is missing', (tester) async {
    await openIssue(tester, '2-2011');

    expect(find.text('Add to collection'), findsOneWidget);
    expect(find.text('♡'), findsOneWidget);
    // Condition only applies once it is yours.
    expect(find.text('Condition'), findsNothing);
  });

  testWidgets('shows an owned issue as held, with its condition', (
    tester,
  ) async {
    await openIssue(tester, '1-2011');

    expect(find.text('In the collection'), findsOneWidget);
    expect(find.text('♥'), findsOneWidget);
    expect(find.text('Condition'), findsOneWidget);
    expect(find.text('not rated yet'), findsOneWidget);
    expect(find.text('Worn'), findsOneWidget);
    expect(find.text('Mint'), findsOneWidget);
  });

  testWidgets('adding an issue that completes a volume rains hearts', (
    tester,
  ) async {
    await openIssue(tester, '2-2011');

    await tapAsync(tester, find.text('Add to collection'));

    expect(magazines.byId('2-2011')!.isOwned, isTrue);
    expect(find.text('Volume 2011 complete ♥'), findsOneWidget);
    expect(find.byType(Hearts), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 3000));
    await settle(tester);
  });

  testWidgets('adding an ordinary issue just says so', (tester) async {
    await openIssue(tester, '3-2012');

    await tapAsync(tester, find.text('Add to collection'));

    expect(find.text('No. 3 / 2012 added'), findsOneWidget);
    expect(find.byType(Hearts), findsNothing);

    await tester.pump(const Duration(milliseconds: 2200));
  });

  testWidgets('setting an issue aside says so', (tester) async {
    await openIssue(tester, '1-2011');

    await tapAsync(tester, find.text('In the collection'));

    expect(magazines.byId('1-2011')!.isOwned, isFalse);
    expect(find.text('No. 1 / 2011 set aside'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2200));
  });

  testWidgets('rates the condition and words it', (tester) async {
    await openIssue(tester, '1-2011');

    await tapAsync(tester, find.text('9'));

    expect(magazines.byId('1-2011')!.conditionScore, 9);
    expect(find.text('Condition set to 9'), findsOneWidget);
    expect(find.text('9 · Mint'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2200));
  });

  testWidgets('counts the vault and offers to add to it', (tester) async {
    await openIssue(tester, '1-2011');

    expect(find.text('Vault'), findsOneWidget);
    expect(find.text('0 photos of this issue'), findsOneWidget);
    expect(find.text('Add photo'), findsOneWidget);
  });

  group('removing an issue', () {
    testWidgets('asks first, naming the issue', (tester) async {
      await openIssue(tester, '1-2011');

      await tester.tap(find.text('Remove this issue from the index'));
      await settle(tester);

      expect(find.text('Remove No. 1 / 2011 from the index?'), findsOneWidget);
      expect(find.text('Its photos and condition go with it.'), findsOneWidget);
      expect(find.text('Keep'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
    });

    testWidgets('keeps it when you say so', (tester) async {
      await openIssue(tester, '1-2011');
      await tester.tap(find.text('Remove this issue from the index'));
      await settle(tester);

      await tester.tap(find.text('Keep'));
      await settle(tester);

      expect(magazines.byId('1-2011'), isNotNull);
      expect(find.byType(IssueScreen), findsOneWidget);
    });

    testWidgets('removes it, steps back and says so', (tester) async {
      await openIssue(tester, '1-2011');
      await tester.tap(find.text('Remove this issue from the index'));
      await settle(tester);

      await tapAsync(tester, find.text('Remove'));

      expect(magazines.byId('1-2011'), isNull);
      expect(find.byType(IssueScreen), findsNothing);
      expect(find.byType(IndexScreen), findsOneWidget);
      expect(find.text('No. 1 / 2011 removed'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2200));
    });
  });
}
