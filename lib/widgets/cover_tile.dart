import 'dart:io';

import 'package:flutter/material.dart';

import '../models/magazine.dart';
import '../theme/edition.dart';
import '../theme/typography.dart';

/// How deeply a cover sits off the page.
///
/// The design gives the same tile a different shadow in each place it appears,
/// from the shallow grid to the hero on the issue screen.
enum CoverDepth {
  /// The "Recently added" rail on the index.
  rail,

  /// The four-up grid on the collection screen.
  grid,

  /// The three-up grid on a year.
  year,

  /// The big cover at the top of an issue.
  hero,

  /// The little thumbnail in a search result, which the design leaves flat.
  flat,
}

/// An issue's cover: the artwork over a tinted block carrying its number.
///
/// The number is not a placeholder that gets swapped out, it is painted
/// underneath and simply covered by the artwork. That is what the design draws,
/// and it means a hand-added issue with no cover of its own, or one whose file
/// has gone missing, still reads as an issue rather than an empty box.
class CoverTile extends StatelessWidget {
  const CoverTile({
    super.key,
    required this.magazine,
    required this.edition,
    required this.numeralSize,
    this.depth = CoverDepth.grid,
    this.desaturate = false,
    this.imageOpacity = 1,
    this.child,
  });

  final Magazine magazine;
  final Edition edition;

  /// The size of the number showing through when there is no artwork.
  final double numeralSize;

  final CoverDepth depth;

  /// Drains the colour from the artwork, how the design marks an issue that is
  /// still missing.
  final bool desaturate;

  /// Fades the artwork alone, leaving the number and the block behind it.
  final double imageOpacity;

  /// Drawn over the cover, for the heart on a year's grid.
  ///
  /// It is drawn last, on top of every mark the tile puts on itself, because
  /// the heart is the one thing on a cover that is tapped.
  final Widget? child;

  /// The seal scales with the number, the tile's one size knob: 12 on a grid
  /// cover, 16 on the rail, 22 on the hero.
  double get _sealSize => (numeralSize * 0.4).clamp(11, 22);

  static const ColorFilter _grey = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  List<BoxShadow> _shadows() {
    // Every depth carries the same hairline; only the cast shadow changes.
    final hairline = BoxShadow(
      color: edition.inkAt(10),
      blurRadius: 0,
      spreadRadius: 1,
    );

    return switch (depth) {
      CoverDepth.flat => const [],
      CoverDepth.rail => [
        const BoxShadow(
          color: Color(0x73000000),
          blurRadius: 14,
          spreadRadius: -6,
          offset: Offset(0, 6),
        ),
        hairline,
      ],
      CoverDepth.grid => [
        const BoxShadow(
          color: Color(0x66000000),
          blurRadius: 10,
          spreadRadius: -5,
          offset: Offset(0, 4),
        ),
        hairline,
      ],
      CoverDepth.year => [
        const BoxShadow(
          color: Color(0x80000000),
          blurRadius: 16,
          spreadRadius: -8,
          offset: Offset(0, 8),
        ),
        hairline,
      ],
      CoverDepth.hero => [
        const BoxShadow(
          color: Color(0x99000000),
          blurRadius: 40,
          spreadRadius: -18,
          offset: Offset(0, 24),
        ),
        hairline,
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    Widget artwork = magazine.hasFileCover
        ? Image.file(
            File(magazine.image),
            fit: BoxFit.cover,
            errorBuilder: _nothing,
          )
        : Image.asset(
            'assets/${magazine.image}',
            fit: BoxFit.cover,
            errorBuilder: _nothing,
          );

    if (desaturate) artwork = ColorFiltered(colorFilter: _grey, child: artwork);
    if (imageOpacity < 1) {
      artwork = Opacity(opacity: imageOpacity, child: artwork);
    }

    return DecoratedBox(
      decoration: BoxDecoration(color: edition.tint, boxShadow: _shadows()),
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Text(
                '${magazine.issue}',
                style: AppType.serif(
                  size: numeralSize,
                  weight: 300,
                  height: 1,
                  color: edition.ink,
                ),
              ),
            ),
            artwork,
            // The draw order, fixed once because three things want a corner of
            // this tile: the number underneath, then the artwork, then the
            // marks the tile puts on itself, then whatever the caller passes.
            if (magazine.isFavourite)
              Align(
                alignment: Alignment.topRight,
                // Outside the desaturation on purpose: a favourite she no
                // longer holds still carries its mark.
                child: _Seal(edition: edition, size: _sealSize),
              ),
            ?child,
          ],
        ),
      ),
    );
  }

  /// A cover that will not load simply leaves the number showing.
  static Widget _nothing(BuildContext context, Object error, StackTrace? s) =>
      const SizedBox.shrink();
}

/// The printer's fleuron, on a small accent block.
///
/// A heart was spoken for twice over: filled and hollow hearts are ownership on
/// the issue button and on the year grid, and the app rains them. The fleuron
/// is a real printer's ornament, which is what this app is dressed as, and it
/// is one of the few Cormorant Garamond actually carries, so it prints in the
/// app's own face rather than in whatever the phone falls back to.
///
/// On a block rather than bare, because a glyph laid straight on artwork is
/// legible over one cover and lost over the next.
class _Seal extends StatelessWidget {
  const _Seal({required this.edition, required this.size});

  final Edition edition;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    color: edition.accent,
    padding: EdgeInsets.symmetric(
      horizontal: size * 0.34,
      vertical: size * 0.2,
    ),
    child: Text(
      '❦',
      style: AppType.serif(size: size, height: 1, color: edition.onAccent),
    ),
  );
}
