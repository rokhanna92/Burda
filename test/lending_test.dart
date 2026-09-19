import 'dart:convert';

import 'package:burda/models/date_label.dart';
import 'package:burda/models/magazine.dart';
import 'package:burda/providers/magazine_provider.dart';
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

/// Two years, one of them complete, and one issue she does not have.
final _seed = [_issue(4, 2019), _issue(5, 2019), _issue(6, 2020, owned: false)];

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

  group('how long it has been', () {
    test('counts whole days as a calendar would', () {
      expect(wholeDays(DateTime(2026, 9, 18, 23), DateTime(2026, 9, 19, 1)), 1);
      expect(wholeDays(DateTime(2026, 9, 19), DateTime(2026, 9, 19)), 0);
      expect(wholeDays(DateTime(2026, 1, 1), DateTime(2026, 3, 2)), 60);
    });

    test('says it the way she would', () {
      final out = DateTime(2026, 3, 1);
      expect(elapsed(out, DateTime(2026, 3, 1)), 'today');
      expect(elapsed(out, DateTime(2026, 3, 2)), 'yesterday');
      expect(elapsed(out, DateTime(2026, 3, 5)), '4 days');
      expect(elapsed(out, DateTime(2026, 3, 10)), 'a week');
      expect(elapsed(out, DateTime(2026, 3, 20)), '3 weeks');
      expect(elapsed(out, DateTime(2026, 4, 10)), 'a month');
      expect(elapsed(out, DateTime(2026, 8, 1)), '5 months');
      expect(elapsed(out, DateTime(2027, 3, 1)), 'a year');
      expect(elapsed(out, DateTime(2029, 3, 1)), '3 years');
    });
  });

  group('a loan', () {
    test('is written and read as one fact', () async {
      await service.lendIssue('4-2019', 'Marta', now: DateTime(2026, 3, 1));

      final stored = await service.getMagazine('4-2019');
      expect(stored!.lentTo, 'Marta');
      expect(stored.lentOn, DateTime(2026, 3, 1));
      expect(stored.isLent, isTrue);
      expect(stored.daysLent(DateTime(2026, 3, 11)), 10);
    });

    test('trims the name, and refuses one made of spaces', () async {
      await service.lendIssue('4-2019', '  Marta  ');
      expect((await service.getMagazine('4-2019'))!.lentTo, 'Marta');

      await service.lendIssue('5-2019', '   ');
      expect((await service.getMagazine('5-2019'))!.isLent, isFalse);
    });

    test('cannot leave a house it is not in', () async {
      await service.lendIssue('6-2020', 'Marta');

      expect((await service.getMagazine('6-2020'))!.isLent, isFalse);
    });

    test('coming back forgets who had it', () async {
      await service.lendIssue('4-2019', 'Marta');
      await service.returnIssue('4-2019');

      final back = await service.getMagazine('4-2019');
      expect(back!.lentTo, isNull);
      expect(back.lentOn, isNull);
      expect(back.isLent, isFalse);
    });

    test('turns to the accent at six months and not before', () {
      const lent = Magazine(
        id: '4-2019',
        title: '4/2019',
        year: 2019,
        image: 'covers/4-2019.jpg',
        isOwned: true,
        lentTo: 'Marta',
      );
      final out = lent.copyWith(lentOn: DateTime(2026, 1, 1));

      expect(out.lentLong(DateTime(2026, 6, 1)), isFalse);
      expect(out.lentLong(DateTime(2026, 7, 5)), isTrue);
    });

    test('survives the row and the file', () async {
      await magazines.lendIssue('4-2019', 'Marta');

      final exported = magazines.toExportJson().first;
      expect(exported['lentTo'], 'Marta');
      expect(Magazine.fromJson(exported.cast()).isLent, isTrue);

      // And a file written before lending existed still reads.
      expect(
        Magazine.fromJson({
          'id': '4-2019',
          'title': '4/2019',
          'year': 2019,
          'image': 'covers/4-2019.jpg',
        }).isLent,
        isFalse,
      );
    });
  });

  group('what lending does not touch', () {
    test('a lent issue is still owned and still counted', () async {
      await magazines.lendIssue('4-2019', 'Marta');

      expect(magazines.ownedCount, 2);
      expect(magazines.completion, 2 / 3);
      expect(magazines.owned.map((m) => m.id), contains('4-2019'));
      expect(magazines.missing.map((m) => m.id), isNot(contains('4-2019')));
      expect(magazines.ownedCountForYear(2019), 2);
      expect(magazines.isYearComplete(2019), isTrue);
      expect(magazines.byId('4-2019')!.isOwned, isTrue);
    });

    test('setting it aside ends the loan with the copy', () async {
      await magazines.lendIssue('4-2019', 'Marta');
      await magazines.toggleOwnership('4-2019');

      final set = magazines.byId('4-2019')!;
      expect(set.isOwned, isFalse);
      expect(
        set.isLent,
        isFalse,
        reason:
            'it cannot be out of a house it is '
            'not in',
      );
    });

    test('lists what is out, longest gone first', () async {
      await service.lendIssue('4-2019', 'Marta', now: DateTime(2026, 1, 1));
      await service.lendIssue('5-2019', 'Ana', now: DateTime(2026, 6, 1));
      await magazines.load();

      expect(magazines.lentCount, 2);
      expect(magazines.lent.map((m) => m.lentTo), ['Marta', 'Ana']);
    });

    test('an issue at a friend s house is not dealt tonight', () async {
      await service.lendIssue('4-2019', 'Marta');

      await app.tonight.load(now: DateTime(2026, 9, 19, 20));

      expect(
        app.tonight.id,
        '5-2019',
        reason: 'the only one still on the shelf',
      );
    });
  });

  group('the screens', () {
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
    }

    Future<void> tapAsync(WidgetTester tester, Finder finder) async {
      await tester.runAsync(() async {
        await tester.tap(finder);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await settle(tester);
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

    Future<void> openIssue(WidgetTester tester, String id) async {
      await pumpApp(tester);
      BurdaNav.of(tester.element(find.byType(NavBar))).push(IssuePage(id));
      await settle(tester);
    }

    testWidgets('offers to lend an issue that is in the house', (tester) async {
      await openIssue(tester, '4-2019');

      expect(find.text('Lending'), findsOneWidget);
      expect(find.text('in the house'), findsOneWidget);
      expect(find.text('Lend this issue'), findsOneWidget);
    });

    testWidgets('lends it through the sheet and says who has it', (
      tester,
    ) async {
      await openIssue(tester, '4-2019');

      await tapAsync(tester, find.text('Lend this issue'));
      expect(find.text('Who has it?'), findsOneWidget);
      expect(
        find.text('Dated today. It is still yours, just not here.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), 'Marta');
      await tapAsync(tester, find.text('Lend it out'));

      expect(magazines.byId('4-2019')!.lentTo, 'Marta');
      expect(find.text('No. 4 / 2019 is with Marta'), findsOneWidget);
      expect(find.text('with Marta'), findsWidgets);
      expect(find.text('Back on the shelf'), findsOneWidget);
      // The band prints on the hero cover.
      expect(find.text('Lent'), findsWidgets);
    });

    testWidgets('refuses a loan with nobody on it', (tester) async {
      await openIssue(tester, '4-2019');

      await tapAsync(tester, find.text('Lend this issue'));
      await tapAsync(tester, find.text('Lend it out'));

      expect(magazines.byId('4-2019')!.isLent, isFalse);
      expect(find.text('Say who has it first'), findsOneWidget);
    });

    testWidgets('prints the day it went out and how long that is', (
      tester,
    ) async {
      await tester.runAsync(
        () => service.lendIssue('4-2019', 'Marta', now: DateTime(2026, 3, 1)),
      );
      await tester.runAsync(magazines.load);
      await pumpApp(tester);
      BurdaNav.of(tester.element(find.byType(NavBar)))
          .push(const IssuePage('4-2019'));
      await settle(tester);

      expect(find.text('Out since 1 March 2026'), findsOneWidget);
    });

    testWidgets('takes it back with one tap', (tester) async {
      await tester.runAsync(() => magazines.lendIssue('4-2019', 'Marta'));
      await openIssue(tester, '4-2019');

      await tapAsync(tester, find.text('Back on the shelf'));

      expect(magazines.byId('4-2019')!.isLent, isFalse);
      expect(find.text('No. 4 / 2019 is back on the shelf'), findsOneWidget);
      expect(find.text('Lend this issue'), findsOneWidget);
    });

    testWidgets('the index lists what is out, and nothing when none is', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(find.text('Out of the house'), findsNothing);

      await tester.runAsync(() => magazines.lendIssue('4-2019', 'Marta'));
      await settle(tester);

      expect(find.text('Out of the house'), findsOneWidget);
      expect(find.text('who has what'), findsOneWidget);
      expect(find.textContaining('with Marta'), findsWidgets);
    });

    testWidgets('setting a lent issue aside says who keeps it', (tester) async {
      await tester.runAsync(() => magazines.lendIssue('4-2019', 'Marta'));
      await openIssue(tester, '4-2019');

      await tapAsync(tester, find.text('In the collection'));

      expect(
        find.text('No. 4 / 2019 set aside, Marta keeps it'),
        findsOneWidget,
      );
    });
  });
}
