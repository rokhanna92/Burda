import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/magazine.dart';
import '../providers/magazine_provider.dart';
import '../shell/burda_nav.dart';
import '../theme/edition.dart';
import '../theme/typography.dart';
import '../widgets/cover_tile.dart';
import '../widgets/page_furniture.dart';

/// Chapter two: every issue, grouped by year, filtered to what is held or
/// what is still out there.
class CollectionScreen extends StatelessWidget {
  const CollectionScreen({
    super.key,
    required this.edition,
    this.showOwned = true,
  });

  final Edition edition;

  /// True for the owned tab, false for missing.
  final bool showOwned;

  @override
  Widget build(BuildContext context) {
    final magazines = context.watch<MagazineProvider>();
    final nav = BurdaNav.of(context);

    final listed = showOwned ? magazines.owned : magazines.missing;
    // Newest volume first, and a year with nothing in it is not printed.
    final years = magazines.years.reversed.where(
      (year) => listed.any((m) => m.year == year),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Eyebrow('Chapter two', edition: edition),
          const SizedBox(height: 4),
          ScreenTitle('Collection', edition: edition),
          const SizedBox(height: 20),
          _Tabs(
            edition: edition,
            showOwned: showOwned,
            ownedCount: magazines.ownedCount,
            missingCount: magazines.missingCount,
            onPick: (owned) => nav.showCollection(owned: owned),
          ),
          const SizedBox(height: 22),
          if (years.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 50),
              child: Text(
                showOwned
                    ? 'Nothing filed yet.\n'
                          'Tap a cover, or the window below, to start.'
                    : 'Not one issue missing.\nThe shelf is complete.',
                textAlign: TextAlign.center,
                style: AppType.serif(
                  size: 19,
                  italic: true,
                  height: 1.4,
                  color: edition.inkAt(60),
                ),
              ),
            ),
          for (final year in years) ...[
            _YearGroup(
              edition: edition,
              year: year,
              issues: listed.where((m) => m.year == year).toList()
                ..sort((a, b) => a.issue.compareTo(b.issue)),
              onOpenYear: () => nav.push(YearPage(year)),
              onOpenIssue: (id) => nav.push(IssuePage(id)),
            ),
            const SizedBox(height: 26),
          ],
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.edition,
    required this.showOwned,
    required this.ownedCount,
    required this.missingCount,
    required this.onPick,
  });

  final Edition edition;
  final bool showOwned;
  final int ownedCount;
  final int missingCount;
  final ValueChanged<bool> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: edition.inkAt(14))),
      ),
      child: Row(
        children: [
          _tab('Owned', ownedCount, selected: showOwned, owned: true),
          const SizedBox(width: 26),
          _tab('Missing', missingCount, selected: !showOwned, owned: false),
        ],
      ),
    );
  }

  Widget _tab(
    String label,
    int count, {
    required bool selected,
    required bool owned,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onPick(owned),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? edition.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          '$label $count',
          style: AppType.smallCaps(
            size: 18,
            trackingEm: 0.12,
            color: selected ? edition.ink : edition.muted,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ),
    );
  }
}

class _YearGroup extends StatelessWidget {
  const _YearGroup({
    required this.edition,
    required this.year,
    required this.issues,
    required this.onOpenYear,
    required this.onOpenIssue,
  });

  final Edition edition;
  final int year;
  final List<Magazine> issues;
  final VoidCallback onOpenYear;
  final ValueChanged<String> onOpenIssue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onOpenYear,
              child: Text(
                '$year',
                style: AppType.serif(
                  size: 30,
                  weight: 300,
                  tabular: true,
                  color: edition.ink,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                '${issues.length} issues',
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: AppType.serif(
                  size: 14,
                  italic: true,
                  color: edition.inkAt(60),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.72,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final (index, magazine) in issues.indexed)
              CoverIn(
                key: ValueKey(magazine.id),
                order: index,
                child: PressScale(
                  scale: 0.95,
                  onTap: () => onOpenIssue(magazine.id),
                  child: CoverTile(
                    magazine: magazine,
                    edition: edition,
                    numeralSize: 30,
                    desaturate: !magazine.isOwned,
                    imageOpacity: magazine.isOwned ? 1 : 0.7,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
