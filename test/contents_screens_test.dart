import 'dart:convert';

import 'package:burda/models/contents_entry.dart';
import 'package:burda/models/garment_tag.dart';
import 'package:burda/providers/contents_provider.dart';
import 'package:burda/screens/contents_reader.dart';
import 'package:burda/screens/issue_screen.dart';
import 'package:burda/screens/vault_screen.dart';
import 'package:burda/services/data_transfer_service.dart';
import 'package:burda/services/database_service.dart';
import 'package:burda/sheets/search_sheet.dart';
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

const _seed = [
  {
    'id': '4-2019',
    'title': '4/2019',
    'year': 2019,
    'image': 'covers/4-2019.jpg',
    'isOwned': true,
  },
  {
    'id': '5-2019',
    'title': '5/2019',
    'year': 2019,
    'image': 'covers/5-2019.jpg',
    'isOwned': true,
  },
];

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late DatabaseService service;
  late TestApp app;
  late ContentsProvider contents;

  setUp(() async {
    service = DatabaseService(
      loadSeed: () async => jsonEncode(_seed),
      databaseName: inMemoryDatabasePath,
    );
    app = TestApp(service);
    await app.load();
    contents = app.contents;
  });

  tearDown(() => service.close());

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  }

  Future<void> tapAsync(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settle(tester);
  }

  /// Writes a page in the real async zone.
  ///
  /// A widget test runs in a fake zone where real I/O never completes, and
  /// putting a page in the index is two round trips to SQLite.
  Future<ContentsEntry> page(
    WidgetTester tester,
    String magazineId,
    String path, {
    GarmentTag? tag,
  }) async {
    late ContentsEntry entry;
    await tester.runAsync(() async {
      entry = await contents.addPage(magazineId: magazineId, path: path);
      if (tag != null) await contents.toggleTag(entry.id, tag);
    });
    return entry;
  }

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1206, 7200);
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

  Future<void> openIssue(WidgetTester tester, String id) async {
    await pumpApp(tester);
    BurdaNav.of(tester.element(find.byType(NavBar))).push(IssuePage(id));
    await settle(tester);
  }

  group('the issue screen', () {
    testWidgets('invites the first photograph', (tester) async {
      await openIssue(tester, '4-2019');

      expect(find.text('Contents'), findsOneWidget);
      expect(find.text('nothing photographed yet'), findsOneWidget);
      expect(
        find.text(
          'Photograph the contents page and you can read it without '
          'getting up.',
        ),
        findsOneWidget,
      );
      expect(find.text('Add a page'), findsOneWidget);
    });

    testWidgets('counts the pages once there are some', (tester) async {
      await page(tester, '4-2019', '/tmp/a.jpg');
      await openIssue(tester, '4-2019');

      expect(find.text('1 page photographed'), findsOneWidget);
      expect(find.textContaining('without getting up'), findsNothing);

      await page(tester, '4-2019', '/tmp/b.jpg');
      await settle(tester);

      expect(find.text('2 pages photographed'), findsOneWidget);
    });

    testWidgets('keeps one issue s pages out of another s', (tester) async {
      await page(tester, '5-2019', '/tmp/a.jpg');
      await openIssue(tester, '4-2019');

      expect(find.text('nothing photographed yet'), findsOneWidget);
    });
  });

  group('the reader', () {
    testWidgets('opens over the nav bar and says where you are', (
      tester,
    ) async {
      await page(tester, '4-2019', '/tmp/a.jpg');
      await page(tester, '4-2019', '/tmp/b.jpg');
      await openIssue(tester, '4-2019');

      BurdaNav.of(tester.element(find.byType(NavBar))).openReader('4-2019');
      await settle(tester);

      expect(find.byType(ContentsReader), findsOneWidget);
      expect(find.text('page 1 of 2'), findsOneWidget);
      expect(find.text('On this page'), findsOneWidget);
      // Every word is offered here, because this is where they are learned.
      expect(find.text('Dresses'), findsOneWidget);
      expect(find.text('Plus sizes'), findsOneWidget);
    });

    testWidgets('says "one page" when there is only one', (tester) async {
      await page(tester, '4-2019', '/tmp/a.jpg');
      await openIssue(tester, '4-2019');

      BurdaNav.of(tester.element(find.byType(NavBar))).openReader('4-2019');
      await settle(tester);

      expect(find.text('one page'), findsOneWidget);
    });

    testWidgets('marks a word, then takes it off again', (tester) async {
      final entry = await page(tester, '4-2019', '/tmp/a.jpg');
      await openIssue(tester, '4-2019');
      BurdaNav.of(tester.element(find.byType(NavBar))).openReader('4-2019');
      await settle(tester);

      await tapAsync(tester, find.text('Jackets'));
      expect(contents.byId(entry.id)!.tags, {GarmentTag.jacket});

      await tapAsync(tester, find.text('Jackets'));
      expect(contents.byId(entry.id)!.tags, isEmpty);
    });

    testWidgets('Back leaves the issue underneath', (tester) async {
      await page(tester, '4-2019', '/tmp/a.jpg');
      await openIssue(tester, '4-2019');
      BurdaNav.of(tester.element(find.byType(NavBar))).openReader('4-2019');
      await settle(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(ContentsReader),
          matching: find.text('Back'),
        ),
      );
      await settle(tester);

      expect(find.byType(ContentsReader), findsNothing);
      expect(find.byType(IssueScreen), findsOneWidget);
    });

    testWidgets('closes itself when its last page is removed', (tester) async {
      await page(tester, '4-2019', '/tmp/a.jpg');
      await openIssue(tester, '4-2019');
      BurdaNav.of(tester.element(find.byType(NavBar))).openReader('4-2019');
      await settle(tester);

      await tapAsync(tester, find.text('Remove this page'));

      expect(find.byType(ContentsReader), findsNothing);
      expect(find.text('Page removed'), findsOneWidget);
      expect(contents.count, 0);
    });

    testWidgets('the system back closes the reader first', (tester) async {
      await page(tester, '4-2019', '/tmp/a.jpg');
      await openIssue(tester, '4-2019');
      BurdaNav.of(tester.element(find.byType(NavBar))).openReader('4-2019');
      await settle(tester);

      await tester.binding.handlePopRoute();
      await settle(tester);

      expect(find.byType(ContentsReader), findsNothing);
      expect(find.byType(IssueScreen), findsOneWidget);
    });
  });

  group('the vault', () {
    testWidgets('never shows a photographed page', (tester) async {
      await page(tester, '4-2019', '/tmp/a.jpg');
      await pumpApp(tester);

      BurdaNav.of(tester.element(find.byType(NavBar))).push(const VaultPage());
      await settle(tester);

      expect(find.byType(VaultScreen), findsOneWidget);
      expect(find.text('0 photos'), findsOneWidget);
      expect(app.magazines.vaultCount, 0);
    });
  });

  group('the search sheet', () {
    Future<void> openSearch(WidgetTester tester) async {
      await pumpApp(tester);
      BurdaNav.of(tester.element(find.byType(NavBar)))
          .openSheet(BurdaSheet.search);
      await settle(tester);
    }

    testWidgets('says so while nothing is tagged', (tester) async {
      await openSearch(tester);

      expect(find.text('What is inside'), findsOneWidget);
      expect(
        find.text(
          'Nothing is tagged yet. Mark what is on a contents page and it '
          'shows up here.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('offers only the words something is tagged with', (
      tester,
    ) async {
      await page(tester, '4-2019', '/tmp/a.jpg', tag: GarmentTag.coat);
      await openSearch(tester);

      expect(find.text('Coats'), findsOneWidget);
      expect(find.text('Dresses'), findsNothing);
      expect(find.textContaining('Nothing is tagged yet'), findsNothing);
    });

    testWidgets('a word lists the issues that carry it', (tester) async {
      await page(tester, '4-2019', '/tmp/a.jpg', tag: GarmentTag.coat);
      await page(tester, '4-2019', '/tmp/b.jpg', tag: GarmentTag.coat);
      await page(tester, '5-2019', '/tmp/c.jpg', tag: GarmentTag.coat);
      await openSearch(tester);

      await tapAsync(tester, find.text('Coats'));

      Finder inSheet(String text) => find.descendant(
        of: find.byType(SearchSheet),
        matching: find.text(text),
      );

      expect(inSheet('2 issues'), findsOneWidget);
      expect(inSheet('No. 4 · 2019'), findsOneWidget);
      expect(inSheet('No. 5 · 2019'), findsOneWidget);
      // Both of 4/2019's pages are counted, even though it is one issue.
      expect(inSheet('2 pages'), findsOneWidget);
      expect(inSheet('1 page'), findsOneWidget);
    });

    testWidgets('an issue from that list opens', (tester) async {
      await page(tester, '4-2019', '/tmp/a.jpg', tag: GarmentTag.skirt);
      await openSearch(tester);

      await tapAsync(tester, find.text('Skirts'));
      await tapAsync(
        tester,
        find.descendant(
          of: find.byType(SearchSheet),
          matching: find.text('No. 4 · 2019'),
        ),
      );

      expect(find.byType(IssueScreen), findsOneWidget);
      expect(find.text('Burda Style, 2019'), findsOneWidget);
    });
  });

  group('the export file', () {
    test('carries the pages, and still reads a bare list', () {
      final written = DataTransferService.bundle(
        magazines: [
          {'id': '4-2019'},
        ],
        contents: [
          {'id': 'a', 'magazineId': '4-2019'},
        ],
        now: DateTime(2026, 9, 19),
      );

      final read = DataTransferService.read(written);
      expect(read.magazines, hasLength(1));
      expect(read.contents, hasLength(1));
      expect(written['version'], DatabaseService.schemaVersion);

      // What the original app wrote, and what her real backup looks like.
      final old = DataTransferService.read([
        {'id': '4-2019'},
      ]);
      expect(old.magazines, hasLength(1));
      expect(old.contents, isEmpty);
      expect(old.settings, isEmpty);

      expect(DataTransferService.read('nonsense').magazines, isEmpty);
    });
  });
}
