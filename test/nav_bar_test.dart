import 'package:burda/theme/edition.dart';
import 'package:burda/theme/season.dart';
import 'package:burda/widgets/nav_bar.dart';
import 'package:burda/widgets/season_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  NavTab? current = NavTab.home,
  Edition edition = Edition.rose,
  ValueChanged<NavTab>? onSelect,
  VoidCallback? onAdd,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: NavBar(
            edition: edition,
            current: current,
            onSelect: onSelect ?? (_) {},
            onAdd: onAdd ?? () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

TextStyle _labelStyle(WidgetTester tester, String label) => tester
    .widget<AnimatedDefaultTextStyle>(
      find
          .ancestor(
            of: find.text(label),
            matching: find.byType(AnimatedDefaultTextStyle),
          )
          .first,
    )
    .style;

Color? _dotColour(WidgetTester tester, String label) {
  final container = tester.widget<AnimatedContainer>(
    find
        .descendant(
          of: find
              .ancestor(of: find.text(label), matching: find.byType(Column))
              .first,
          matching: find.byType(AnimatedContainer),
        )
        .first,
  );
  return (container.decoration as BoxDecoration?)?.color;
}

void main() {
  group('SeasonScene', () {
    test('every édition has a scene', () {
      for (final edition in Edition.all) {
        expect(
          () => SeasonScene.of(edition),
          returnsNormally,
          reason: 'édition ${edition.id} has no scene',
        );
      }
    });

    test('matches the design season for each édition', () {
      expect(SeasonScene.of(Edition.rose).season, Season.petals);
      expect(SeasonScene.of(Edition.ete).season, Season.sun);
      expect(SeasonScene.of(Edition.automne).season, Season.leaves);
      expect(SeasonScene.of(Edition.hiver).season, Season.snow);
      expect(SeasonScene.of(Edition.maroon).season, Season.dust);
      expect(SeasonScene.of(Edition.nuit).season, Season.stars);
      expect(SeasonScene.of(Edition.noir).season, Season.stars);
      expect(SeasonScene.of(Edition.bordeaux).season, Season.embers);
    });

    test('the sky runs top to bottom and the ground fades upward', () {
      final scene = SeasonScene.of(Edition.hiver);

      expect(scene.sky.begin, Alignment.topCenter);
      expect(scene.sky.end, Alignment.bottomCenter);
      expect(scene.ground.begin, Alignment.bottomCenter);
      expect(scene.ground.colors.last.a, 0);
    });
  });

  group('NavBar', () {
    testWidgets('prints the four tabs and the window', (tester) async {
      await _pump(tester);

      for (final tab in NavTab.values) {
        expect(find.text(tab.label), findsOneWidget);
      }
      expect(find.byType(SeasonWindow), findsOneWidget);
    });

    testWidgets('lights the current tab and mutes the rest', (tester) async {
      await _pump(tester, current: NavTab.years);

      expect(_labelStyle(tester, 'Years').color, Edition.rose.ink);
      expect(_labelStyle(tester, 'Index').color, Edition.rose.muted);
      expect(_dotColour(tester, 'Years'), Edition.rose.accent);
      expect(_dotColour(tester, 'Index'), Colors.transparent);
    });

    testWidgets('leaves every tab unlit while a page is pushed', (
      tester,
    ) async {
      await _pump(tester, current: null);

      for (final tab in NavTab.values) {
        expect(_labelStyle(tester, tab.label).color, Edition.rose.muted);
        expect(_dotColour(tester, tab.label), Colors.transparent);
      }
    });

    testWidgets('reports the tab that was tapped', (tester) async {
      NavTab? picked;
      await _pump(tester, onSelect: (tab) => picked = tab);

      await tester.tap(find.text('Profile'));
      expect(picked, NavTab.profile);
    });

    testWidgets('opens the add sheet from the window', (tester) async {
      var added = false;
      await _pump(tester, onAdd: () => added = true);

      await tester.tap(find.byType(SeasonWindow));
      expect(added, isTrue);
    });

    testWidgets('fits every label inside its own column', (tester) async {
      // The frame the design is drawn against, where "Collection" wrapped onto
      // a second line.
      tester.view.physicalSize = const Size(1206, 2622);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await _pump(tester);

      // Four tabs share what is left after the 18px gutters and the 76px the
      // window sits in.
      final column = (402 - 36 - 76) / 4;

      for (final tab in NavTab.values) {
        final text = tester.widget<Text>(find.text(tab.label));
        expect(text.maxLines, 1, reason: tab.label);
        expect(text.softWrap, isFalse, reason: tab.label);

        // Fits, so it is neither wrapped nor cut off.
        expect(
          tester.getSize(find.text(tab.label)).width,
          lessThanOrEqualTo(column),
          reason: '${tab.label} is wider than its column',
        );
      }
    });

    testWidgets('sets all four labels at the same size', (tester) async {
      tester.view.physicalSize = const Size(1206, 2622);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await _pump(tester);

      final sizes = {
        for (final tab in NavTab.values)
          _labelStyle(tester, tab.label).fontSize,
      };
      expect(sizes, hasLength(1), reason: 'the labels should match each other');
      expect(sizes.single, lessThanOrEqualTo(15));
    });

    testWidgets('sits on the system inset without padding it out', (
      tester,
    ) async {
      await _pump(tester);

      final padding = tester.widget<Padding>(
        find
            .descendant(of: find.byType(NavBar), matching: find.byType(Padding))
            .first,
      );
      // No bottom inset in the test view, so only the small floor remains.
      expect((padding.padding as EdgeInsets).bottom, 8);
    });

    testWidgets('takes its colours from the édition', (tester) async {
      await _pump(tester, edition: Edition.noir, current: NavTab.home);

      expect(_labelStyle(tester, 'Index').color, Edition.noir.ink);
      expect(_dotColour(tester, 'Index'), Edition.noir.accent);
    });
  });
}
