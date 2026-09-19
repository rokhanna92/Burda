import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/date_label.dart';
import '../models/magazine.dart';
import '../providers/magazine_provider.dart';
import '../shell/burda_nav.dart';
import '../theme/edition.dart';
import '../theme/season.dart';
import '../theme/typography.dart';
import '../widgets/cover_tile.dart';
import '../widgets/page_furniture.dart';
import '../widgets/season_window.dart';

/// One month, every year of it: every May the magazine has printed.
///
/// This is how sewing is actually planned. Linen in May, coats in September,
/// and the seventeen Mays on one page are the answer to what to make next
/// month.
class MonthScreen extends StatelessWidget {
  const MonthScreen({super.key, required this.edition, required this.month});

  final Edition edition;

  /// 1 to 12.
  final int month;

  @override
  Widget build(BuildContext context) {
    final magazines = context.watch<MagazineProvider>();
    final nav = BurdaNav.of(context);
    final issues = magazines.magazinesForMonth(month);
    final owned = issues.where((m) => m.isOwned).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              BackLink(edition: edition, onTap: nav.back),
              // The nav bar's porthole, in the corner of the page like a
              // printer's mark, drifting this month's weather rather than the
              // édition's.
              SeasonWindow(
                edition: edition,
                size: 44,
                season: Season.ofMonth(month),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Shrinks rather than clips: "September" is three times the width
              // of "May", where a year is always four figures.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 210),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    kMonths[month - 1],
                    style: AppType.serif(
                      size: 84,
                      weight: 300,
                      trackingEm: -0.03,
                      height: 0.85,
                      color: edition.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '$owned of ${issues.length}\nin the collection',
                    textAlign: TextAlign.end,
                    style: AppType.serif(
                      size: 17,
                      italic: true,
                      height: 1.25,
                      color: edition.inkAt(70),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ProgressRule(
            edition: edition,
            fraction: issues.isEmpty ? 0 : owned / issues.length,
            duration: const Duration(milliseconds: 700),
          ),
          const SizedBox(height: 26),
          GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 14,
            childAspectRatio: 0.58,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final (index, magazine) in issues.indexed)
                CoverIn(
                  key: ValueKey(magazine.id),
                  order: index,
                  child: _MonthCover(
                    edition: edition,
                    magazine: magazine,
                    onOpen: () => nav.push(IssuePage(magazine.id)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One year's issue of this month, captioned by its year.
///
/// The year is the caption because it is the only thing telling these tiles
/// apart: every plate underneath prints the same numeral, since every issue
/// here is No. 5. No heart either: on a volume the heart is how twelve issues
/// get filed twelve at a time, and here she is choosing something to sew, with
/// the issue screen one tap away.
class _MonthCover extends StatelessWidget {
  const _MonthCover({
    required this.edition,
    required this.magazine,
    required this.onOpen,
  });

  final Edition edition;
  final Magazine magazine;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: PressScale(
          scale: 0.96,
          onTap: onOpen,
          child: Opacity(
            opacity: magazine.isOwned ? 1 : 0.55,
            child: CoverTile(
              magazine: magazine,
              edition: edition,
              numeralSize: 36,
              depth: CoverDepth.year,
              desaturate: !magazine.isOwned,
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '${magazine.year}',
        style: AppType.serif(size: 15, tabular: true, color: edition.ink),
      ),
    ],
  );
}
