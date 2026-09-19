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
class CollectionScreen extends StatefulWidget {
  const CollectionScreen({
    super.key,
    required this.edition,
    this.showOwned = true,
  });

  final Edition edition;

  /// True for the owned tab, false for missing.
  final bool showOwned;

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  /// Which way the shelf is read.
  ///
  /// It opens by year every time: that is the order it was built in and the one
  /// she knows. Best first is a question she asks, not a state she lives in.
  bool _byRating = false;

  @override
  Widget build(BuildContext context) {
    final edition = widget.edition;
    final magazines = context.watch<MagazineProvider>();
    final nav = BurdaNav.of(context);

    final listed = widget.showOwned ? magazines.owned : magazines.missing;
    // Newest volume first, and a year with nothing in it is not printed.
    final years = magazines.years.reversed.where(
      (year) => listed.any((m) => m.year == year),
    );
    final judged = listed.where((m) => m.isJudged).toList()
      ..sort(MagazineProvider.compareByRating);

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
            showOwned: widget.showOwned,
            ownedCount: magazines.ownedCount,
            missingCount: magazines.missingCount,
            onPick: (owned) => nav.showCollection(owned: owned),
          ),
          const SizedBox(height: 10),
          _OrderSwitch(
            edition: edition,
            byRating: _byRating,
            onOrder: (byRating) => setState(() => _byRating = byRating),
          ),
          const SizedBox(height: 16),
          if (_byRating) ...[
            if (judged.isEmpty)
              _EmptyNote(
                'Nothing judged yet.\n'
                'Open an issue and say what you think of what is inside.',
                edition: edition,
              )
            else ...[
              SectionHeader(
                'Best first',
                edition: edition,
                note: '${judged.length} judged',
              ),
              const SizedBox(height: 12),
              _CoverGrid(
                edition: edition,
                issues: judged,
                onOpenIssue: (id) => nav.push(IssuePage(id)),
              ),
              if (listed.length > judged.length) ...[
                const SizedBox(height: 16),
                // The one listing in the app that does not show everything its
                // tab counts, which is why it says so.
                Text(
                  '${listed.length - judged.length} more are not judged yet.',
                  style: AppType.serif(
                    size: 15,
                    italic: true,
                    color: edition.inkAt(60),
                  ),
                ),
              ],
            ],
          ] else ...[
            if (years.isEmpty)
              _EmptyNote(
                widget.showOwned
                    ? 'Nothing filed yet.\n'
                          'Tap a cover, or the window below, to start.'
                    : 'Not one issue missing.\nThe shelf is complete.',
                edition: edition,
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
        ],
      ),
    );
  }
}

/// The centred italic paragraph both empty states are set in.
class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.text, {required this.edition});

  final String text;
  final Edition edition;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 50),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: AppType.serif(
        size: 19,
        italic: true,
        height: 1.4,
        color: edition.inkAt(60),
      ),
    ),
  );
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
        crossAxisAlignment: CrossAxisAlignment.end,
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

/// Which way the shelf is read, printed as both orders with the one in force
/// set in ink.
///
/// Both are printed because a single toggle showing one word never says whether
/// that word is the state or the offer. It sits under the tabs rather than
/// beside them: at the width this app is drawn for, four words and two counts
/// do not share a line.
class _OrderSwitch extends StatelessWidget {
  const _OrderSwitch({
    required this.edition,
    required this.byRating,
    required this.onOrder,
  });

  final Edition edition;
  final bool byRating;
  final ValueChanged<bool> onOrder;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      _order('by year', chosen: !byRating),
      Text(' · ', style: AppType.serif(size: 14, color: edition.muted)),
      _order('best first', chosen: byRating),
    ],
  );

  Widget _order(String label, {required bool chosen}) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => onOrder(label == 'best first'),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        label,
        style: AppType.serif(
          size: 14,
          italic: true,
          color: chosen ? edition.ink : edition.muted,
        ),
      ),
    ),
  );
}

/// The four-up grid of covers, which both readings of the shelf lay out.
class _CoverGrid extends StatelessWidget {
  const _CoverGrid({
    required this.edition,
    required this.issues,
    required this.onOpenIssue,
  });

  final Edition edition;
  final List<Magazine> issues;
  final ValueChanged<String> onOpenIssue;

  @override
  Widget build(BuildContext context) => GridView.count(
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
  );
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
        _CoverGrid(edition: edition, issues: issues, onOpenIssue: onOpenIssue),
      ],
    );
  }
}
