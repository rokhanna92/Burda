import 'package:burda/models/collector_rank.dart';
import 'package:burda/sheets/about_sheet.dart';
import 'package:burda/sheets/rank_sheet.dart';
import 'package:burda/theme/edition.dart';
import 'package:burda/widgets/sheet_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  VoidCallback? onClose,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: Colors.white)),
            Positioned.fill(
              child: SheetScaffold(
                edition: Edition.rose,
                onClose: onClose ?? () {},
                child: child,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('SheetScaffold', () {
    testWidgets('rises into place over a dimmed page', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SheetScaffold(
              edition: Edition.rose,
              onClose: () {},
              child: const Text('contents'),
            ),
          ),
        ),
      );

      // The sheet's own slide, not the one the route is wrapped in.
      Offset slide() => tester
          .widget<SlideTransition>(
            find.descendant(
              of: find.byType(SheetScaffold),
              matching: find.byType(SlideTransition),
            ),
          )
          .position
          .value;

      await tester.pump();
      expect(slide().dy, greaterThan(0.5));

      await tester.pumpAndSettle();
      expect(slide(), Offset.zero);
    });

    testWidgets('closes when the dimmed area is tapped', (tester) async {
      var closed = false;
      await _pump(tester, const Text('contents'), onClose: () => closed = true);

      await tester.tapAt(const Offset(200, 60));
      expect(closed, isTrue);
    });

    testWidgets('does not close when the sheet itself is tapped', (
      tester,
    ) async {
      var closed = false;
      await _pump(tester, const Text('contents'), onClose: () => closed = true);

      await tester.tap(find.text('contents'));
      expect(closed, isFalse);
    });

    testWidgets('is set on paper with a grab handle', (tester) async {
      await _pump(tester, const Text('contents'));

      final panel = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.text('contents'),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((panel.decoration as BoxDecoration).color, Edition.rose.paper);
    });
  });

  group('RankSheet', () {
    testWidgets('names the rung you are on and the climb left', (tester) async {
      await _pump(
        tester,
        const RankSheet(edition: Edition.rose, ownedCount: 30),
      );

      expect(find.text('Fabric Fanatic'), findsNWidgets(2)); // heading + rung
      expect(
        find.text('30 issues owned · 20 more to Sartorial Stylist'),
        findsOneWidget,
      );
    });

    testWidgets('lists all five rungs with their bands', (tester) async {
      await _pump(
        tester,
        const RankSheet(edition: Edition.rose, ownedCount: 0),
      );

      for (final rank in CollectorRank.ladder) {
        expect(find.text(rank.band), findsOneWidget, reason: rank.name);
      }
      expect(find.text('0–9 issues'), findsOneWidget);
    });

    testWidgets('picks the current rung out in the accent', (tester) async {
      await _pump(
        tester,
        const RankSheet(edition: Edition.rose, ownedCount: 120),
      );

      final band = tester.widget<Text>(find.text('100+ issues'));
      expect(band.style!.color, Edition.rose.accent);

      final other = tester.widget<Text>(find.text('0–9 issues'));
      expect(other.style!.color, Edition.rose.ink);
    });

    testWidgets('says so at the top of the ladder', (tester) async {
      await _pump(
        tester,
        const RankSheet(edition: Edition.rose, ownedCount: 184),
      );

      expect(
        find.text('184 issues owned · the top of the ladder'),
        findsOneWidget,
      );
    });
  });

  group('AboutSheet', () {
    testWidgets('prints the three paragraphs as the original wrote them', (
      tester,
    ) async {
      await _pump(tester, const AboutSheet(edition: Edition.rose));

      expect(find.text('About Burda Style'), findsOneWidget);
      expect(find.text('Version 2.0'), findsOneWidget);
      for (final paragraph in AboutSheet.paragraphs) {
        expect(find.text(paragraph), findsOneWidget);
      }
    });
  });
}
