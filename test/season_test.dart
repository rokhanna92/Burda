import 'package:burda/theme/edition.dart';
import 'package:burda/theme/season.dart';
import 'package:burda/widgets/season_particles.dart';
import 'package:burda/widgets/season_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('the window carries the weather of its édition', (tester) async {
    await _pump(tester, const SeasonWindow(edition: Edition.hiver));

    final particles = tester.widget<SeasonParticles>(
      find.byType(SeasonParticles),
    );
    expect(particles.season, Season.snow);
    expect(particles.accent, Edition.hiver.accent);

    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('changing édition changes the weather', (tester) async {
    await _pump(tester, const SeasonWindow(edition: Edition.rose));
    expect(
      tester.widget<SeasonParticles>(find.byType(SeasonParticles)).season,
      Season.petals,
    );

    await _pump(tester, const SeasonWindow(edition: Edition.bordeaux));
    expect(
      tester.widget<SeasonParticles>(find.byType(SeasonParticles)).season,
      Season.embers,
    );

    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('keeps drifting frame after frame', (tester) async {
    await _pump(
      tester,
      const SizedBox.square(
        dimension: 60,
        child: SeasonParticles(
          season: Season.leaves,
          accent: Color(0xFFC2445F),
        ),
      ),
    );

    // Several frames without an exception is the thing being checked: the
    // painter runs every one of them.
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('every season paints without complaint', (tester) async {
    for (final season in Season.values) {
      await _pump(
        tester,
        SizedBox.square(
          dimension: 60,
          child: SeasonParticles(
            season: season,
            accent: const Color(0xFFC2445F),
          ),
        ),
      );
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.takeException(), isNull, reason: season.name);
    }
  });

  testWidgets('stops when it is taken off the screen', (tester) async {
    await _pump(
      tester,
      const SizedBox.square(
        dimension: 60,
        child: SeasonParticles(season: Season.snow, accent: Color(0xFFC2445F)),
      ),
    );
    expect(find.byType(SeasonParticles), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Gone, and its ticker with it: the test would fail on a live ticker.
    expect(find.byType(SeasonParticles), findsNothing);
  });
}
