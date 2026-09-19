import 'dart:convert';

import 'package:burda/models/make.dart';
import 'package:burda/providers/make_provider.dart';
import 'package:burda/screens/issue_screen.dart';
import 'package:burda/screens/queue_screen.dart';
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
  late TestApp app;
  late MakeProvider makes;

  setUp(() async {
    service = DatabaseService(
      loadSeed: () async => jsonEncode(_seed),
      databaseName: inMemoryDatabasePath,
    );
    app = TestApp(service);
    await app.load();
    makes = app.makes;
  });

  tearDown(() => service.close());

  group('the queue itself', () {
    test('an issue put in the queue is a make that is waiting', () async {
      await makes.queueIssue('4-2019');

      expect(makes.isQueued('4-2019'), isTrue);
      expect(makes.isQueued('5-2019'), isFalse);
      expect(makes.queuedCount, 1);
      expect(makes.queued.single.status, MakeStatus.queued);
      expect(makes.queued.single.magazineId, '4-2019');
      // It is a make like any other, so the journal shows it too.
      expect(makes.count, 1);
    });

    test('starting it is a status change, not a new row', () async {
      final queued = await makes.queueIssue('4-2019');
      await makes.setStatus(queued.id, MakeStatus.cutting);

      expect(makes.count, 1, reason: 'the same row moved');
      expect(makes.isQueued('4-2019'), isFalse);
      expect(makes.onTheGo.single.id, queued.id);
    });

    test('keeps the newest first', () async {
      await makes.queueIssue('4-2019', now: DateTime(2026, 1));
      await makes.queueIssue('5-2019', now: DateTime(2026, 2));
      await makes.queueIssue('6-2019', now: DateTime(2026, 3));

      expect(makes.queued.map((m) => m.magazineId), [
        '6-2019',
        '5-2019',
        '4-2019',
      ]);
    });

    test('moving one up passes exactly the one above it', () async {
      await makes.queueIssue('4-2019', now: DateTime(2026, 1));
      await makes.queueIssue('5-2019', now: DateTime(2026, 2));
      final last = await makes.queueIssue('6-2019', now: DateTime(2026, 3));

      // 6/2019 is already first, so there is nothing above it to pass.
      await makes.moveUp(last.id);
      expect(makes.queued.first.magazineId, '6-2019');

      final bottom = makes.queued.last;
      await makes.moveUp(bottom.id);
      expect(makes.queued.map((m) => m.magazineId), [
        '6-2019',
        '4-2019',
        '5-2019',
      ]);

      await makes.moveUp(bottom.id);
      expect(makes.queued.map((m) => m.magazineId), [
        '4-2019',
        '6-2019',
        '5-2019',
      ]);
    });

    test('taking one out of the queue takes the row with it', () async {
      final queued = await makes.queueIssue('4-2019');

      await makes.unqueue(queued.id);

      expect(makes.count, 0);
      expect(makes.isQueued('4-2019'), isFalse);
    });

    test('will not unqueue something already being sewn', () async {
      final queued = await makes.queueIssue('4-2019');
      await makes.setStatus(queued.id, MakeStatus.sewing);

      await makes.unqueue(queued.id);

      expect(makes.count, 1, reason: 'a garment in progress is not a plan');
    });
  });

  group('the queue screen', () {
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

    Future<void> queue(
      WidgetTester tester,
      String id, {
      required DateTime at,
    }) async {
      await tester.runAsync(() => makes.queueIssue(id, now: at));
    }

    Future<void> open(WidgetTester tester, BurdaPage page) async {
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
      BurdaNav.of(tester.element(find.byType(NavBar))).push(page);
      await settle(tester);
    }

    testWidgets('says what to do when nothing is waiting', (tester) async {
      await open(tester, const QueuePage());

      expect(find.byType(QueueScreen), findsOneWidget);
      expect(find.text('0 to make'), findsOneWidget);
      expect(
        find.text(
          'Nothing waiting.\n'
          'Open an issue and put it in the sew queue.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('numbers the queue and teaches the gesture', (tester) async {
      await queue(tester, '4-2019', at: DateTime(2026, 1));
      await queue(tester, '5-2019', at: DateTime(2026, 2));
      await open(tester, const QueuePage());

      expect(find.text('2 to make'), findsOneWidget);
      expect(find.text('Next first'), findsOneWidget);
      expect(find.text('↑ moves one up'), findsOneWidget);
      expect(find.text('01'), findsOneWidget);
      expect(find.text('02'), findsOneWidget);
      expect(find.text('No. 5 · 2019'), findsOneWidget);
      expect(find.text('no pattern noted yet'), findsNWidgets(2));
      // Nothing to move above the first row, so only one arrow.
      expect(find.text('↑'), findsOneWidget);
    });

    testWidgets('the arrow moves one up', (tester) async {
      await queue(tester, '4-2019', at: DateTime(2026, 1));
      await queue(tester, '5-2019', at: DateTime(2026, 2));
      await open(tester, const QueuePage());

      expect(makes.queued.first.magazineId, '5-2019');

      await tapAsync(tester, find.text('↑'));

      expect(makes.queued.first.magazineId, '4-2019');
    });

    testWidgets('the cross takes one out and says so', (tester) async {
      await queue(tester, '4-2019', at: DateTime(2026, 1));
      await open(tester, const QueuePage());

      await tapAsync(tester, find.text('×'));

      expect(makes.queuedCount, 0);
      expect(find.text('Taken out of the queue'), findsOneWidget);
    });

    testWidgets('a row opens the issue it came from', (tester) async {
      await queue(tester, '4-2019', at: DateTime(2026, 1));
      await open(tester, const QueuePage());

      await tapAsync(tester, find.text('No. 4 · 2019'));

      expect(find.byType(IssueScreen), findsOneWidget);
      expect(find.text('Burda Style, 2019'), findsOneWidget);
    });
  });

  group('the issue screen', () {
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
    }

    Future<void> openIssue(WidgetTester tester, String id) async {
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
      BurdaNav.of(tester.element(find.byType(NavBar))).push(IssuePage(id));
      await settle(tester);
    }

    testWidgets('offers to put an owned issue in the queue', (tester) async {
      await openIssue(tester, '4-2019');

      expect(find.text('Put in the sew queue'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.text('Put in the sew queue'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await settle(tester);

      expect(makes.isQueued('4-2019'), isTrue);
      expect(find.text('No. 4 / 2019 is in the sew queue'), findsOneWidget);
      // The button becomes the way through rather than a second add.
      expect(find.text('In the sew queue'), findsOneWidget);
    });

    testWidgets('does not offer it for an issue she does not own', (
      tester,
    ) async {
      await openIssue(tester, '7-2019');

      expect(find.text('Put in the sew queue'), findsNothing);
    });

    testWidgets('once queued the button goes to the queue', (tester) async {
      await tester.runAsync(() => makes.queueIssue('4-2019'));
      await openIssue(tester, '4-2019');

      await tester.runAsync(() async {
        await tester.tap(find.text('In the sew queue'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await settle(tester);

      expect(find.byType(QueueScreen), findsOneWidget);
    });
  });
}
