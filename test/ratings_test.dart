import 'dart:convert';

import 'package:burda/models/magazine.dart';
import 'package:burda/providers/magazine_provider.dart';
import 'package:burda/screens/collection_screen.dart';
import 'package:burda/screens/issue_screen.dart';
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

  group('the two judgments', () {
    test('five marks write an even score on the ten point scale', () {
      expect(Magazine.contentScoreFor(1), 2);
      expect(Magazine.contentScoreFor(5), 10);

      const judged = Magazine(
        id: '4-2019',
        title: '4/2019',
        year: 2019,
        image: 'covers/4-2019.jpg',
        contentScore: 8,
      );
      expect(judged.contentMarksFilled, 4);
      expect(judged.contentLabel, 'a lot to sew');
    });

    test('an odd score from a hand edited file still draws', () {
      const odd = Magazine(
        id: '4-2019',
        title: '4/2019',
        year: 2019,
        image: 'covers/4-2019.jpg',
        contentScore: 7,
      );
      expect(odd.contentMarksFilled, 4);
    });

    test('names every mark, because the app words everything', () {
      expect(Magazine.contentLabelFor(1), 'not for me');
      expect(Magazine.contentLabelFor(3), 'a good issue');
      expect(Magazine.contentLabelFor(5), 'one of the best');
    });

    test('is not judged until she says something', () {
      const plain = Magazine(
        id: '4-2019',
        title: '4/2019',
        year: 2019,
        image: 'covers/4-2019.jpg',
      );
      expect(plain.isJudged, isFalse);
      expect(plain.contentLabel, isNull);
      expect(plain.copyWith(isFavourite: true).isJudged, isTrue);
      expect(plain.copyWith(contentScore: 6).isJudged, isTrue);
    });

    test('a score and a mark survive the row and the file', () async {
      await magazines.setContentScore('4-2019', 8);
      await magazines.toggleFavourite('4-2019');

      final stored = await service.getMagazine('4-2019');
      expect(stored!.contentScore, 8);
      expect(stored.isFavourite, isTrue);

      final exported = magazines.toExportJson().first;
      expect(exported['contentScore'], 8);
      expect(exported['isFavourite'], isTrue);
      expect(Magazine.fromJson(exported.cast()).contentScore, 8);
    });

    test('an export written before this lands still reads', () {
      final old = Magazine.fromJson({
        'id': '4-2019',
        'title': '4/2019',
        'year': 2019,
        'image': 'covers/4-2019.jpg',
        'isOwned': true,
      });

      expect(old.isFavourite, isFalse);
      expect(old.contentScore, isNull);
    });

    test('setting a copy aside keeps what she thought of it', () async {
      await magazines.setContentScore('4-2019', 10);
      await magazines.toggleFavourite('4-2019');
      await magazines.setCondition('4-2019', 9);

      await magazines.toggleOwnership('4-2019');

      final set = magazines.byId('4-2019')!;
      expect(set.isOwned, isFalse);
      expect(set.conditionScore, isNull, reason: 'the paper is not hers');
      expect(set.contentScore, 10, reason: 'the printing did not change');
      expect(set.isFavourite, isTrue);
    });

    test('best first puts her marks above any score', () {
      const base = Magazine(
        id: '1-2019',
        title: '1/2019',
        year: 2019,
        image: 'covers/1-2019.jpg',
      );
      final marked = base.copyWith(isFavourite: true);
      final ten = base.copyWith(contentScore: 10);
      final six = base.copyWith(contentScore: 6);

      final sorted = [six, ten, marked]..sort(MagazineProvider.compareByRating);
      expect(sorted.map((m) => m.contentScore), [null, 10, 6]);
      expect(sorted.first.isFavourite, isTrue);
    });
  });

  group('the issue screen', () {
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

    Future<void> openIssue(WidgetTester tester, String id) async {
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
      BurdaNav.of(tester.element(find.byType(NavBar))).push(IssuePage(id));
      await settle(tester);
    }

    testWidgets('keeps the paper and the printing apart', (tester) async {
      await openIssue(tester, '4-2019');

      expect(find.byType(IssueScreen), findsOneWidget);
      expect(find.text('Condition'), findsOneWidget);
      expect(find.text('not rated yet'), findsOneWidget);
      expect(find.text('Inside'), findsOneWidget);
      expect(find.text('not judged yet'), findsOneWidget);
      // Five marks, against the condition row's ten boxes.
      expect(find.text('◇'), findsNWidgets(5));
      expect(find.text('Mark as a favourite'), findsOneWidget);
    });

    testWidgets('a mark writes a score and says what it means', (tester) async {
      await openIssue(tester, '4-2019');

      await tapAsync(tester, find.text('◇').at(3));

      expect(magazines.byId('4-2019')!.contentScore, 8);
      expect(find.text('Inside: a lot to sew'), findsOneWidget);
      expect(find.text('a lot to sew'), findsOneWidget);
      expect(find.text('◆'), findsNWidgets(4));
      expect(find.text('◇'), findsOneWidget);
    });

    testWidgets('the fleuron marks a favourite and says so', (tester) async {
      await openIssue(tester, '4-2019');

      await tapAsync(tester, find.text('Mark as a favourite'));

      expect(magazines.byId('4-2019')!.isFavourite, isTrue);
      expect(find.text('Marked a favourite ❦'), findsOneWidget);
      expect(find.text('A favourite'), findsOneWidget);
      // On the button, and on the hero cover's own seal.
      expect(find.text('❦'), findsNWidgets(2));

      await tapAsync(tester, find.text('A favourite'));
      expect(magazines.byId('4-2019')!.isFavourite, isFalse);
      expect(find.text('No longer a favourite'), findsOneWidget);
    });

    testWidgets('is not offered for an issue she neither holds nor judged', (
      tester,
    ) async {
      await openIssue(tester, '7-2019');

      expect(find.text('Inside'), findsNothing);
    });

    testWidgets('stays reachable on an issue she has judged and set aside', (
      tester,
    ) async {
      await tester.runAsync(() => magazines.toggleFavourite('7-2019'));
      await openIssue(tester, '7-2019');

      expect(find.text('Inside'), findsOneWidget);
      expect(find.text('A favourite'), findsOneWidget);
    });
  });

  group('the collection screen', () {
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
    }

    Future<void> openCollection(WidgetTester tester) async {
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
      BurdaNav.of(tester.element(find.byType(NavBar))).goTab(NavTab.collection);
      await settle(tester);
    }

    testWidgets('offers both orders and opens on the one she knows', (
      tester,
    ) async {
      await openCollection(tester);

      expect(find.byType(CollectionScreen), findsOneWidget);
      expect(find.text('by year'), findsOneWidget);
      expect(find.text('best first'), findsOneWidget);
      expect(find.text('2019'), findsOneWidget, reason: 'the year group');
    });

    testWidgets('best first says when nothing is judged', (tester) async {
      await openCollection(tester);

      await tester.tap(find.text('best first'));
      await settle(tester);

      expect(
        find.text(
          'Nothing judged yet.\n'
          'Open an issue and say what you think of what is inside.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('best first lists what she judged, and counts the rest', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await magazines.toggleFavourite('5-2019');
        await magazines.setContentScore('6-2019', 8);
      });
      await openCollection(tester);

      await tester.tap(find.text('best first'));
      await settle(tester);

      expect(find.text('Best first'), findsOneWidget);
      expect(find.text('2 judged'), findsOneWidget);
      expect(find.text('1 more are not judged yet.'), findsOneWidget);
      // The year heading is gone: this reading is one grid.
      expect(find.text('2019'), findsNothing);
    });
  });
}
