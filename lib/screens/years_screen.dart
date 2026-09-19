import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/magazine.dart';
import '../models/series.dart';
import '../providers/magazine_provider.dart';
import '../shell/burda_nav.dart';
import '../theme/edition.dart';
import '../theme/motion.dart';
import '../theme/typography.dart';
import '../widgets/page_furniture.dart';

/// What one year looks like on the shelf.
class _Volume {
  const _Volume({
    required this.year,
    required this.series,
    required this.owned,
    required this.total,
  });

  final int year;
  final Series series;
  final int owned;
  final int total;

  double get fraction => total == 0 ? 0 : owned / total;
  int get missing => total - owned;

  /// How tall the spine stands.
  ///
  /// The design varies it by year so the shelf is not a flat row of identical
  /// blocks, using the year itself rather than anything random, which keeps a
  /// spine the same height every time you come back to it.
  double get height => (78 + (year * 13) % 23) / 100;
}

/// Chapter three: the years standing as volumes on two shelves.
class YearsScreen extends StatelessWidget {
  const YearsScreen({super.key, required this.edition});

  final Edition edition;

  /// How many volumes stand on one shelf.
  static const int perShelf = 8;

  @override
  Widget build(BuildContext context) {
    final magazines = context.watch<MagazineProvider>();
    final nav = BurdaNav.of(context);

    // One run of boards per shelf, each under its own heading. With a single
    // shelf no heading is drawn and the screen is what it always was.
    final boards = [
      for (final shelf in magazines.startedShelves)
        (
          shelf: shelf,
          volumes: [
            for (final year in shelf.years)
              _Volume(
                year: year,
                series: shelf.series,
                owned: magazines.ownedCountForYear(year, series: shelf.series),
                total: magazines
                    .magazinesForYear(year, series: shelf.series)
                    .length,
              ),
          ],
        ),
    ];

    // Only a shelf whose size is known can be complete or be missing anything:
    // an open one is full by definition and would inflate both counts.
    final counted = [
      for (final board in boards)
        if (board.shelf.series.counted) ...board.volumes,
    ];
    final volumes = [for (final board in boards) ...board.volumes];
    final complete = counted.where((v) => v.fraction == 1).length;
    final incomplete = counted.where((v) => v.missing > 0).toList();
    final missing = incomplete.fold(0, (sum, v) => sum + v.missing);

    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Eyebrow('Chapter three', edition: edition),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: ScreenTitle('Years', edition: edition)),
              const SizedBox(width: 10),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '$complete complete volumes',
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.serif(
                      size: 16,
                      italic: true,
                      color: edition.inkAt(65),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          if (volumes.isEmpty)
            Text(
              'The shelf is bare.\nFile a year to put something on it.',
              textAlign: TextAlign.center,
              style: AppType.serif(
                size: 19,
                italic: true,
                height: 1.4,
                color: edition.inkAt(60),
              ),
            ),
          for (final board in boards) ...[
            if (magazines.manyShelves) ...[
              SectionHeader(board.shelf.series.title, edition: edition),
              const SizedBox(height: 14),
            ],
            for (final run in _runs(board.volumes)) ...[
              _Board(
                edition: edition,
                volumes: run,
                onOpen: (volume) =>
                    nav.push(YearPage(volume.year, series: volume.series)),
              ),
              const SizedBox(height: 34),
            ],
          ],
          if (incomplete.isNotEmpty) ...[
            const SizedBox(height: 2),
            SectionHeader(
              'Still missing',
              edition: edition,
              note: '$missing issues',
            ),
            const SizedBox(height: 4),
            for (final volume in incomplete)
              _MissingRow(
                edition: edition,
                volume: volume,
                issues: magazines.magazinesForYear(
                  volume.year,
                  series: volume.series,
                )..sort((a, b) => a.issue.compareTo(b.issue)),
                onOpen: () =>
                    nav.push(YearPage(volume.year, series: volume.series)),
              ),
          ],
        ],
      ),
    );
  }
}

/// Breaks a shelf's volumes into boards of [YearsScreen.perShelf].
///
/// A top-level function rather than a line in build, because it now runs once
/// per shelf rather than once.
List<List<_Volume>> _runs(List<_Volume> volumes) => [
  for (var at = 0; at < volumes.length; at += YearsScreen.perShelf)
    volumes.sublist(
      at,
      at + YearsScreen.perShelf > volumes.length
          ? volumes.length
          : at + YearsScreen.perShelf,
    ),
];

/// One board: up to eight spines standing on it.
///
/// Named board rather than shelf, since Shelf now means the data three lines
/// above it.
class _Board extends StatelessWidget {
  const _Board({
    required this.edition,
    required this.volumes,
    required this.onOpen,
  });

  final Edition edition;
  final List<_Volume> volumes;
  final ValueChanged<_Volume> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 200,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (index, volume) in volumes.indexed) ...[
                  if (index > 0) const SizedBox(width: 7),
                  Expanded(
                    child: _Spine(
                      edition: edition,
                      volume: volume,
                      order: index,
                      onTap: () => onOpen(volume),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        // The board they stand on.
        Container(
          height: 7,
          decoration: BoxDecoration(
            color: edition.ink,
            boxShadow: const [
              BoxShadow(
                color: Color(0x80000000),
                blurRadius: 16,
                spreadRadius: -8,
                offset: Offset(0, 10),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A single year, standing up, filled from the bottom to the share held.
class _Spine extends StatefulWidget {
  const _Spine({
    required this.edition,
    required this.volume,
    required this.order,
    required this.onTap,
  });

  final Edition edition;
  final _Volume volume;
  final int order;
  final VoidCallback onTap;

  @override
  State<_Spine> createState() => _SpineState();
}

class _SpineState extends State<_Spine> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final edition = widget.edition;
    final volume = widget.volume;
    // A nearly full spine is dark enough to carry the paper colour.
    final labelColour = volume.fraction >= 0.92 ? edition.paper : edition.ink;
    final countColour = volume.fraction > 0.12 ? edition.paper : edition.ink;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedSlide(
        // Lifts off the shelf a little as it is pressed.
        offset: _pressed ? const Offset(0, -0.03) : Offset.zero,
        duration: const Duration(milliseconds: 220),
        curve: AppMotion.standard,
        child: FractionallySizedBox(
          heightFactor: volume.height,
          alignment: Alignment.bottomCenter,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: edition.tint,
              border: Border.all(color: edition.inkAt(14)),
            ),
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: volume.fraction),
                      duration: Duration(milliseconds: 900 + widget.order * 45),
                      curve: AppMotion.standard,
                      builder: (context, filled, _) => FractionallySizedBox(
                        heightFactor: filled,
                        alignment: Alignment.bottomCenter,
                        child: ColoredBox(color: edition.accent),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: RotatedBox(
                        quarterTurns: 1,
                        child: Text(
                          '${volume.year}',
                          style: AppType.serif(
                            size: 17,
                            trackingEm: 0.14,
                            tabular: true,
                            color: labelColour,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${volume.owned}',
                        style: AppType.serif(
                          size: 12,
                          tabular: true,
                          color: countColour,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A year in the "Still missing" list, with a mark for every issue.
class _MissingRow extends StatelessWidget {
  const _MissingRow({
    required this.edition,
    required this.volume,
    required this.issues,
    required this.onOpen,
  });

  final Edition edition;
  final _Volume volume;
  final List<Magazine> issues;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return HairlineRow(
      edition: edition,
      onTap: onOpen,
      verticalPadding: 13,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${volume.year}',
            style: AppType.serif(size: 24, tabular: true, color: edition.ink),
          ),
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                children: [
                  for (final issue in issues) ...[
                    const SizedBox(width: 2),
                    Container(
                      width: 9,
                      height: 13,
                      decoration: BoxDecoration(
                        color: issue.isOwned
                            ? edition.accent
                            : Colors.transparent,
                        border: Border.all(color: edition.inkAt(35)),
                      ),
                    ),
                    const SizedBox(width: 2),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(
            width: 74,
            child: Text(
              '${volume.missing} missing',
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: AppType.serif(
                size: 15,
                italic: true,
                color: edition.inkAt(65),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
