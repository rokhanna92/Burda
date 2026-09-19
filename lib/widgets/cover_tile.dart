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
  final Widget? child;

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
