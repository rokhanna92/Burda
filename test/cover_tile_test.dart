import 'package:burda/models/magazine.dart';
import 'package:burda/theme/edition.dart';
import 'package:burda/widgets/cover_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _bundled = Magazine(
  id: '7-2024',
  title: '7/2024',
  year: 2024,
  image: 'covers/7-2024.jpg',
  isOwned: true,
);

/// An issue added by hand, whose cover is a file the user picked.
const _picked = Magazine(
  id: '3-2026',
  title: '3/2026',
  year: 2026,
  image: '/storage/emulated/0/Pictures/burda.jpg',
);

Future<void> _pump(WidgetTester tester, CoverTile tile) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: 90, height: 125, child: tile)),
    ),
  ),
);

void main() {
  testWidgets('paints the issue number under the artwork', (tester) async {
    await _pump(
      tester,
      const CoverTile(
        magazine: _bundled,
        edition: Edition.rose,
        numeralSize: 30,
      ),
    );

    // The number, not the "7/2024" title: the design prints the issue alone.
    expect(find.text('7'), findsOneWidget);

    final style = tester.widget<Text>(find.text('7')).style!;
    expect(style.fontSize, 30);
    expect(style.color, Edition.rose.ink);
  });

  testWidgets('sits the cover on a tinted block', (tester) async {
    await _pump(
      tester,
      const CoverTile(
        magazine: _bundled,
        edition: Edition.hiver,
        numeralSize: 30,
      ),
    );

    final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
    expect((box.decoration as BoxDecoration).color, Edition.hiver.tint);
  });

  testWidgets('reads a bundled cover from assets', (tester) async {
    await _pump(
      tester,
      const CoverTile(
        magazine: _bundled,
        edition: Edition.rose,
        numeralSize: 30,
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image)).image;
    expect(image, isA<AssetImage>());
    expect((image as AssetImage).assetName, 'assets/covers/7-2024.jpg');
  });

  testWidgets('reads a hand-picked cover from the file', (tester) async {
    await _pump(
      tester,
      const CoverTile(
        magazine: _picked,
        edition: Edition.rose,
        numeralSize: 30,
      ),
    );

    expect(tester.widget<Image>(find.byType(Image)).image, isA<FileImage>());
  });

  testWidgets('drains the colour from a missing issue', (tester) async {
    await _pump(
      tester,
      const CoverTile(
        magazine: _bundled,
        edition: Edition.rose,
        numeralSize: 30,
        desaturate: true,
      ),
    );

    expect(find.byType(ColorFiltered), findsOneWidget);
  });

  testWidgets('leaves an owned cover in full colour', (tester) async {
    await _pump(
      tester,
      const CoverTile(
        magazine: _bundled,
        edition: Edition.rose,
        numeralSize: 30,
      ),
    );

    expect(find.byType(ColorFiltered), findsNothing);
    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets('fades the artwork without fading the number', (tester) async {
    await _pump(
      tester,
      const CoverTile(
        magazine: _bundled,
        edition: Edition.rose,
        numeralSize: 30,
        imageOpacity: 0.7,
      ),
    );

    final fade = tester.widget<Opacity>(find.byType(Opacity));
    expect(fade.opacity, 0.7);
    // The number is a sibling of the faded artwork, not inside it.
    expect(
      find.descendant(of: find.byType(Opacity), matching: find.text('7')),
      findsNothing,
    );
  });

  testWidgets('deepens the shadow from the rail to the hero', (tester) async {
    for (final (depth, blur) in const [
      (CoverDepth.grid, 10.0),
      (CoverDepth.rail, 14.0),
      (CoverDepth.year, 16.0),
      (CoverDepth.hero, 40.0),
    ]) {
      await _pump(
        tester,
        CoverTile(
          magazine: _bundled,
          edition: Edition.rose,
          numeralSize: 30,
          depth: depth,
        ),
      );

      final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
      final shadows = (box.decoration as BoxDecoration).boxShadow!;

      expect(shadows.first.blurRadius, blur, reason: '$depth');
      // Every depth keeps the same hairline around the block.
      expect(shadows.last.color, Edition.rose.inkAt(10), reason: '$depth');
    }
  });

  testWidgets('a flat cover casts no shadow', (tester) async {
    await _pump(
      tester,
      const CoverTile(
        magazine: _bundled,
        edition: Edition.rose,
        numeralSize: 26,
        depth: CoverDepth.flat,
      ),
    );

    final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
    expect((box.decoration as BoxDecoration).boxShadow, isEmpty);
  });

  testWidgets('draws an overlay on top of the cover', (tester) async {
    await _pump(
      tester,
      const CoverTile(
        magazine: _bundled,
        edition: Edition.rose,
        numeralSize: 36,
        child: Text('♥'),
      ),
    );

    expect(find.text('♥'), findsOneWidget);
  });
}
