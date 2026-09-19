import 'package:burda/theme/edition.dart';
import 'package:burda/widgets/falling_hearts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  Edition edition = Edition.rose,
  VoidCallback? onDone,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: FallingHearts(edition: edition, onDone: onDone),
            ),
          ],
        ),
      ),
    ),
  );
}

List<double> _tops(WidgetTester tester) => tester
    .widgetList<Positioned>(find.byType(Positioned))
    .where((p) => p.top != null)
    .map((p) => p.top!)
    .toList();

/// The heart nearest the top. New ones keep being released above it, so this
/// stays negative for most of the shower.
double _highest(WidgetTester tester) =>
    _tops(tester).reduce((a, b) => a < b ? a : b);

/// The heart nearest the bottom: the one leading the shower down.
double _leading(WidgetTester tester) =>
    _tops(tester).reduce((a, b) => a > b ? a : b);

void main() {
  testWidgets('hearts arrive from above the top edge', (tester) async {
    await _pump(tester);

    // Step forward a frame at a time until the first heart appears: wherever
    // that is, it must still be above the top, so none is ever seen coming
    // out of nothing.
    var frames = 0;
    while (find.text('♥').evaluate().isEmpty && frames < 30) {
      await tester.pump(const Duration(milliseconds: 16));
      frames++;
    }

    expect(find.text('♥'), findsWidgets, reason: 'nothing fell at all');
    expect(_highest(tester), lessThan(0));

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('they fall, rather than rise', (tester) async {
    await _pump(tester);
    await tester.pump(const Duration(milliseconds: 200));
    final early = _leading(tester);

    await tester.pump(const Duration(milliseconds: 400));
    final later = _leading(tester);

    // The heart out in front keeps getting lower. Watching the topmost one
    // would prove nothing: fresh hearts keep appearing above it.
    expect(later, greaterThan(early), reason: 'the shower should be falling');

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('the shower builds and then clears', (tester) async {
    await _pump(tester);

    await tester.pump(const Duration(milliseconds: 400));
    final middle = find.text('♥').evaluate().length;
    expect(middle, greaterThan(4));

    // Everything has passed the bottom by the time the shower is declared
    // over: no heart is cut off in mid-air.
    await tester.pump(FallingHearts.shower);
    expect(find.text('♥'), findsNothing);
  });

  testWidgets('it says when it is over', (tester) async {
    var done = false;
    await _pump(tester, onDone: () => done = true);

    await tester.pump(const Duration(milliseconds: 1000));
    expect(done, isFalse);

    await tester.pump(FallingHearts.shower);
    expect(done, isTrue);
  });

  testWidgets('the hearts are the colours of the édition', (tester) async {
    await _pump(tester, edition: Edition.hiver);
    await tester.pump(const Duration(milliseconds: 500));

    final colours = tester
        .widgetList<Text>(find.text('♥'))
        .map((t) => t.style!.color!)
        .toSet();

    expect(colours, isNotEmpty);
    expect(
      colours,
      contains(Edition.hiver.accent),
      reason: 'the accent should be among them',
    );
    // And shades of it, not one flat colour.
    expect(colours.length, greaterThan(1));

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('every édition can rain', (tester) async {
    for (final edition in Edition.all) {
      await _pump(tester, edition: edition);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: edition.id);
      await tester.pump(const Duration(seconds: 3));
    }
  });

  testWidgets('it lets taps through to what is underneath', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => tapped = true,
                ),
              ),
              const Positioned.fill(
                child: FallingHearts(edition: Edition.rose),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tapAt(const Offset(200, 300));
    expect(tapped, isTrue, reason: 'the shower must not swallow a tap');

    await tester.pump(const Duration(seconds: 3));
  });
}
