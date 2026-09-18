import 'package:burda/services/quote_service.dart';
import 'package:burda/theme/app_theme.dart';
import 'package:burda/theme/palette.dart';
import 'package:burda/widgets/quote_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The two colours the glitch layers are drawn in.
const _red = Color(0xFFFF3B3B);
const _cyan = Color(0xFF00E5FF);

int _layersColoured(WidgetTester tester, Color color) => tester
    .widgetList<Text>(find.byType(Text))
    .where((text) => text.style?.color == color)
    .length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Warm the cache outside the fake async zone so the widget's own load
    // resolves immediately.
    await QuoteService.load();
  });

  Future<void> pumpQuote(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Palette.pink),
        home: const Scaffold(body: Center(child: QuoteDisplay())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
  }

  testWidgets('a fact appears in quotes', (tester) async {
    await pumpQuote(tester);

    final quote = tester.widgetList<Text>(find.byType(Text)).first.data ?? '';
    expect(quote.startsWith('"'), isTrue);
    expect(quote.endsWith('"'), isTrue);
  });

  testWidgets('a change flashes red and cyan, then settles', (tester) async {
    await pumpQuote(tester);

    // Mid glitch, right after the quote lands.
    expect(_layersColoured(tester, _red), 1);
    expect(_layersColoured(tester, _cyan), 1);

    // Once it has run its course, only the plain text is left.
    await tester.pump(QuoteDisplay.glitchDuration);
    expect(_layersColoured(tester, _red), 0);
    expect(_layersColoured(tester, _cyan), 0);
    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('the fact changes on its own', (tester) async {
    await pumpQuote(tester);
    final first = tester.widgetList<Text>(find.byType(Text)).last.data;

    await tester.pump(QuoteDisplay.interval);
    await tester.pump(const Duration(milliseconds: 16));

    final second = tester.widgetList<Text>(find.byType(Text)).last.data;
    expect(second, isNot(first));

    // Leave no timer running, or the test fails on teardown.
    await tester.pump(QuoteDisplay.glitchDuration);
  });
}
