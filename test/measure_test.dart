import 'dart:convert';

import 'package:burda/models/garment_tag.dart';
import 'package:burda/models/measurements.dart';
import 'package:burda/models/size_chart.dart';
import 'package:burda/providers/measure_provider.dart';
import 'package:burda/screens/measure_screen.dart';
import 'package:burda/screens/profile_screen.dart';
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

const _seed = [
  {
    'id': '4-2019',
    'title': '4/2019',
    'year': 2019,
    'image': 'covers/4-2019.jpg',
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
  late MeasureProvider measure;

  setUp(() async {
    service = DatabaseService(
      loadSeed: () async => jsonEncode(_seed),
      databaseName: inMemoryDatabasePath,
    );
    app = TestApp(service);
    await app.load();
    measure = app.measure;
  });

  tearDown(() => service.close());

  group('the chart', () {
    test('gives the size nearest the measurement', () {
      expect(SizeChart.sizeForBust(92), 40);
      expect(SizeChart.sizeForBust(93), 40);
      expect(SizeChart.sizeForHip(100), 40);
      expect(SizeChart.sizeForHip(104), 42);
    });

    test('rounds a measurement between two rows up', () {
      // 90 sits exactly between 38 (88) and 40 (92): a seam can be taken in
      // and it cannot be let out.
      expect(SizeChart.sizeForBust(90), 40);
    });

    test('says nothing rather than guessing far off the table', () {
      expect(SizeChart.sizeForBust(60), isNull);
      expect(SizeChart.sizeForBust(140), isNull);
      // One size step past the end is still a size.
      expect(SizeChart.sizeForBust(126), 52);
      expect(SizeChart.sizeForBust(76), 34);
    });

    test('numbers a size differently in each run', () {
      expect(SizeRun.standard.numberFor(40), '40');
      expect(SizeRun.petite.numberFor(40), '20');
      expect(SizeRun.tall.numberFor(40), '80');
    });

    test('puts a height in its run, and no height in the standard one', () {
      expect(SizeRun.forHeight(155), SizeRun.petite);
      expect(SizeRun.forHeight(168), SizeRun.standard);
      expect(SizeRun.forHeight(175), SizeRun.tall);
      expect(SizeRun.forHeight(null), SizeRun.standard);
    });

    test('prints a half only when the half is real', () {
      expect(centimetres(92), '92');
      expect(centimetres(41.5), '41.5');
    });
  });

  group('Measurements', () {
    test('takes tops from the bust and skirts from the hip', () {
      const measure = Measurements(bust: 92, hip: 108);

      expect(measure.topSize, 40);
      expect(measure.skirtSize, 44);
      expect(measure.sizeFor(GarmentTag.dress), 40);
      expect(measure.sizeFor(GarmentTag.blouse), 40);
      expect(measure.sizeFor(GarmentTag.skirt), 44);
      expect(measure.sizeFor(GarmentTag.trousers), 44);
    });

    test('a size she chose beats the chart everywhere', () {
      const measure = Measurements(bust: 92, hip: 108, chosenSize: 42);

      expect(measure.topSize, 42);
      expect(measure.skirtSize, 42);
      expect(measure.sizeFor(GarmentTag.skirt), 42);
      expect(measure.offChart, isFalse);
    });

    test('says when a bust is off the chart rather than guessing', () {
      expect(const Measurements(bust: 60).offChart, isTrue);
      expect(const Measurements(bust: 60).size, isNull);
      // Unless she has said what she cuts, in which case there is no question.
      expect(const Measurements(bust: 60, chosenSize: 34).offChart, isFalse);
    });

    test('reads a comma the way it reads a point', () {
      final measure = Measurements.fromSettings({
        MeasureKeys.bust: '92,5',
        MeasureKeys.backWaist: '41.5',
      });

      expect(measure.bust, 92.5);
      expect(measure.backWaist, 41.5);
    });

    test('writes a null for every number she rubbed out', () {
      const measure = Measurements(bust: 92);
      final written = measure.toSettings();

      expect(written[MeasureKeys.bust], '92');
      // Present and null, not absent: absent would leave the old number.
      expect(written.containsKey(MeasureKeys.waist), isTrue);
      expect(written[MeasureKeys.waist], isNull);
      expect(written.containsKey(MeasureKeys.hip), isTrue);
      expect(written[MeasureKeys.hip], isNull);
    });

    test('is not taken until a number is in it', () {
      expect(Measurements.none.isTaken, isFalse);
      expect(const Measurements(chosenSize: 40).isTaken, isFalse);
      expect(const Measurements(bust: 92).isTaken, isTrue);
    });
  });

  group('the settings table', () {
    test('a measurement written is one read back', () async {
      await measure.save(
        const Measurements(bust: 92, waist: 76, hip: 100),
        now: DateTime(2026, 5, 4),
      );

      final fresh = MeasureProvider(database: service);
      await fresh.load();

      expect(fresh.measurements.bust, 92);
      expect(fresh.measurements.hip, 100);
      expect(fresh.measurements.takenOn, DateTime(2026, 5, 4));
      expect(fresh.measurements.size, 40);
    });

    test('an emptied number stops being hers', () async {
      await measure.save(const Measurements(bust: 92, waist: 76));
      expect(measure.measurements.waist, 76);

      // Taken again with the waist left empty.
      await measure.save(const Measurements(bust: 92));

      final fresh = MeasureProvider(database: service);
      await fresh.load();
      expect(fresh.measurements.waist, isNull, reason: 'the row was deleted');
      expect(fresh.measurements.bust, 92);
    });

    test(
      'writes a set in one batch, so a date never outruns its numbers',
      () async {
        await measure.save(
          const Measurements(bust: 92, hip: 100),
          now: DateTime(2026, 5, 4),
        );

        final stored = await service.getSettings();
        expect(stored[MeasureKeys.bust], '92');
        expect(stored[MeasureKeys.hip], '100');
        expect(
          stored[MeasureKeys.takenOn],
          DateTime(2026, 5, 4).toIso8601String(),
        );
      },
    );

    test('one setting at a time, for the features that keep one', () async {
      await service.setSetting('collection.completedOn', '2026-09-19');
      expect(await service.getSetting('collection.completedOn'), '2026-09-19');

      await service.clearSetting('collection.completedOn');
      expect(await service.getSetting('collection.completedOn'), isNull);
    });

    test('the export carries every namespace, not only this one', () async {
      await measure.save(const Measurements(bust: 92));
      await service.setSetting('collection.completedOn', '2026-09-19');

      final exported = await measure.exportSettings();

      expect(exported[MeasureKeys.bust], '92');
      expect(
        exported['collection.completedOn'],
        '2026-09-19',
        reason: 'the one fact that cannot be worked out again',
      );
    });

    test('an import writes back what it was given and re-reads', () async {
      await measure.import({
        MeasureKeys.bust: '96',
        'collection.completedOn': '2026-09-19',
        'ignored': 7,
      });

      expect(measure.measurements.bust, 96);
      expect(await service.getSetting('collection.completedOn'), '2026-09-19');
      expect(await service.getSetting('ignored'), isNull);
    });

    test('the journal is offered her size, and only as a hint', () async {
      await measure.save(const Measurements(bust: 92, hip: 108));

      expect(measure.sizeFor(GarmentTag.dress), 40);
      expect(measure.sizeFor(GarmentTag.skirt), 44);
    });
  });

  group('the measurements page', () {
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
    }

    Future<void> open(WidgetTester tester) async {
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
      BurdaNav.of(tester.element(find.byType(NavBar)))
          .push(const MeasurePage());
      await settle(tester);
    }

    testWidgets('invites the first measuring', (tester) async {
      await open(tester);

      expect(find.byType(MeasureScreen), findsOneWidget);
      expect(find.text('Not taken yet'), findsOneWidget);
      expect(
        find.text('Take your measurements and the size follows.'),
        findsOneWidget,
      );
      expect(find.text('Take your measurements'), findsOneWidget);
      expect(find.text('not set'), findsNWidgets(5));
    });

    testWidgets('leads with the size and where it came from', (tester) async {
      await tester.runAsync(
        () => measure.save(
          const Measurements(bust: 92, waist: 76, hip: 100, height: 168),
          now: DateTime(2026, 5, 4),
        ),
      );
      await open(tester);

      expect(find.text('Taken 4 May 2026'), findsOneWidget);
      expect(find.text('40'), findsWidgets);
      expect(find.text('your Burda size\nfrom the chart'), findsOneWidget);
      expect(find.text('German 40 · UK 12 · US 8'), findsOneWidget);
      expect(find.text('168 cm puts you in Standard'), findsOneWidget);
      expect(
        find.text(
          'A guide, not a rule. The table in the issue you are cutting from '
          'is the one that counts.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('prints both sizes when the bust and the hip disagree', (
      tester,
    ) async {
      await tester.runAsync(
        () => measure.save(const Measurements(bust: 92, hip: 108)),
      );
      await open(tester);

      expect(find.text('40 / 44'), findsOneWidget);
      expect(
        find.text('your Burda size\n40 for tops, 44 for skirts'),
        findsOneWidget,
      );
    });

    testWidgets('says so when she picked the size herself', (tester) async {
      await tester.runAsync(
        () => measure.save(const Measurements(bust: 92, chosenSize: 42)),
      );
      await open(tester);

      expect(find.text('your Burda size\nset by you'), findsOneWidget);
      expect(find.text('42'), findsWidgets);
    });

    testWidgets('says plainly when a bust is off the chart', (tester) async {
      await tester.runAsync(() => measure.save(const Measurements(bust: 60)));
      await open(tester);

      expect(
        find.text(
          "Your bust is off the chart. Burda's table runs from 80 to 122 cm.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('names the plus run for a size that is printed there', (
      tester,
    ) async {
      await tester.runAsync(() => measure.save(const Measurements(bust: 104)));
      await open(tester);

      expect(find.text('Burda Style Plus prints this size.'), findsOneWidget);
    });

    testWidgets('prints the chart, the runs and the ease', (tester) async {
      await open(tester);

      expect(find.text('The chart'), findsOneWidget);
      expect(find.text('your sizes are marked'), findsOneWidget);
      expect(find.text('Size'), findsOneWidget);
      // "Back" is the chart's column head and the page's own back link.
      expect(find.text('Back'), findsNWidgets(2));
      expect(find.text('The runs'), findsOneWidget);
      expect(find.textContaining('Petite'), findsOneWidget);
      expect(find.text('Ease'), findsOneWidget);
      expect(find.textContaining('Semi fitted'), findsOneWidget);
      expect(
        find.text(
          'For a blouse or a dress. A jacket takes about 2 cm more, a coat '
          'about 5.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('takes the measurements through the sheet', (tester) async {
      await open(tester);

      await tester.tap(find.text('Take your measurements'));
      await settle(tester);

      expect(find.text('In centimetres'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '92');

      await tester.runAsync(() async {
        await tester.tap(find.text('Save measurements'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await settle(tester);

      expect(measure.measurements.bust, 92);
      expect(find.text('Measurements saved'), findsOneWidget);
      expect(find.text('Take them again'), findsOneWidget);
    });

    testWidgets('refuses to save an empty sheet', (tester) async {
      await open(tester);

      await tester.tap(find.text('Take your measurements'));
      await settle(tester);
      await tester.runAsync(() async {
        await tester.tap(find.text('Save measurements'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await settle(tester);

      expect(measure.measurements.isTaken, isFalse);
      expect(find.text('Write a number first'), findsOneWidget);
    });

    testWidgets('the profile points at it', (tester) async {
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
      BurdaNav.of(tester.element(find.byType(NavBar))).goTab(NavTab.profile);
      await settle(tester);

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('Measurements'), findsOneWidget);
      expect(find.text('for when you cut'), findsOneWidget);

      await tester.tap(find.textContaining('Your measurements'));
      await settle(tester);

      expect(find.byType(MeasureScreen), findsOneWidget);
    });
  });
}
