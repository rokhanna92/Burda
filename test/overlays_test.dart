import 'package:burda/theme/edition.dart';
import 'package:burda/widgets/hearts.dart';
import 'package:burda/widgets/toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _framed(Widget child) => MaterialApp(
  home: Scaffold(
    body: Stack(children: [Positioned.fill(child: child)]),
  ),
);

/// The toast's own fade, not the one MaterialApp wraps every route in.
final _toastFade = find.descendant(
  of: find.byType(Toast),
  matching: find.byType(FadeTransition),
);

void main() {
  group('Toast', () {
    testWidgets('prints the message in paper on ink', (tester) async {
      await tester.pumpWidget(
        _framed(const Toast(message: 'Note added', edition: Edition.rose)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Note added'), findsOneWidget);

      final style = tester.widget<Text>(find.text('Note added')).style!;
      expect(style.color, Edition.rose.paper);
      expect(style.fontStyle, FontStyle.italic);

      final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
      expect((box.decoration as BoxDecoration).color, Edition.rose.ink);
    });

    testWidgets('fades and lifts into place', (tester) async {
      await tester.pumpWidget(
        _framed(
          const Toast(message: 'Condition set to 8', edition: Edition.rose),
        ),
      );

      double opacity() =>
          tester.widget<FadeTransition>(_toastFade).opacity.value;

      await tester.pump();
      expect(opacity(), lessThan(0.2));

      await tester.pumpAndSettle();
      expect(opacity(), 1);
    });

    testWidgets('replays when the message changes', (tester) async {
      await tester.pumpWidget(
        _framed(const Toast(message: 'first', edition: Edition.rose)),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _framed(const Toast(message: 'second', edition: Edition.rose)),
      );
      await tester.pump();

      expect(
        tester.widget<FadeTransition>(_toastFade).opacity.value,
        lessThan(1),
      );
      expect(find.text('second'), findsOneWidget);
    });

    testWidgets('never wraps to a second line', (tester) async {
      await tester.pumpWidget(
        _framed(
          const Toast(
            message: 'No. 12 / 2024 added to the collection',
            edition: Edition.rose,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<Text>(find.byType(Text).first).maxLines, 1);
    });
  });

  group('Hearts', () {
    testWidgets('releases fourteen hearts in the accent colour', (
      tester,
    ) async {
      await tester.pumpWidget(_framed(const Hearts(edition: Edition.nuit)));
      // Far enough in that every heart has been released.
      await tester.pump(const Duration(milliseconds: 1400));

      expect(find.text('♥'), findsNWidgets(Hearts.count));
      expect(
        tester.widget<Text>(find.text('♥').first).style!.color,
        Edition.nuit.accent,
      );

      await tester.pumpAndSettle();
    });

    testWidgets('holds a heart invisible until its turn comes', (tester) async {
      await tester.pumpWidget(_framed(const Hearts(edition: Edition.rose)));
      await tester.pump(const Duration(milliseconds: 1));

      final opacities = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .map((o) => o.opacity)
          .toList();

      // The first is on its way in, the last is still waiting.
      expect(opacities.first, greaterThan(0));
      expect(opacities.last, 0);

      await tester.pumpAndSettle();
    });

    testWidgets('reports when the celebration is over', (tester) async {
      var done = false;
      await tester.pumpWidget(
        _framed(Hearts(edition: Edition.rose, onDone: () => done = true)),
      );

      await tester.pump(const Duration(milliseconds: 2000));
      expect(done, isFalse);

      await tester.pumpAndSettle();
      expect(done, isTrue);
    });
  });
}
