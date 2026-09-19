import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/collector_rank.dart';
import '../models/date_label.dart';
import '../models/magazine.dart';
import '../models/note_provider.dart';
import '../providers/magazine_provider.dart';
import '../providers/make_provider.dart';
import '../providers/theme_provider.dart';
import '../shell/burda_nav.dart';
import '../theme/edition.dart';
import '../theme/typography.dart';
import '../widgets/cover_tile.dart';
import '../widgets/nav_bar.dart';
import '../widgets/page_furniture.dart';

/// The index: the collection's front page.
///
/// Reads as the contents page of a magazine, which is why the title is set in
/// the script face, the stats sit under a printer's double rule, and each way
/// into the app is a numbered line rather than a button.
class IndexScreen extends StatelessWidget {
  const IndexScreen({super.key, required this.edition, this.today});

  final Edition edition;

  /// Overridable so a test is not at the mercy of the calendar.
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final magazines = context.watch<MagazineProvider>();
    final makes = context.watch<MakeProvider>();
    final noteCount = context.select<NoteProvider, int>((n) => n.count);
    final editionName = context.select<ThemeProvider, String>(
      (theme) => theme.edition.name,
    );
    final nav = BurdaNav.of(context);
    final now = today ?? DateTime.now();

    final owned = magazines.ownedCount;
    final total = magazines.totalCount;
    final percent = total == 0 ? 0 : (owned / total * 100).round();

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Gutter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Eyebrow(
                  "The collector's index",
                  edition: edition,
                  centred: true,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 2, 10, 0),
                  child: Text(
                    'Burda Style',
                    textAlign: TextAlign.center,
                    // Larger than the design's 66px: FleurDeLeah is drawn
                    // small on the body and this is the one place it appears,
                    // so it is worth giving it the room.
                    style: AppType.logo(
                      size: 82,
                      height: 1.2,
                      color: edition.accent,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Édition $editionName · ${monthAndYear(now)}',
                  textAlign: TextAlign.center,
                  style: AppType.smallCaps(
                    size: 13,
                    trackingEm: 0.2,
                    color: edition.ink,
                  ),
                ),
                const SizedBox(height: 14),
                _DoubleRule(edition: edition),
                const SizedBox(height: 22),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Shrinks rather than clips: "100%" is a whole digit
                    // wider than the numbers before it, and it is the one
                    // number she is working towards.
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 210),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '$percent%',
                          style: AppType.serif(
                            size: 104,
                            weight: 300,
                            trackingEm: -0.03,
                            height: 0.82,
                            tabular: true,
                            color: edition.ink,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          'of the collection\n$owned of $total issues',
                          style: AppType.serif(
                            size: 19,
                            italic: true,
                            height: 1.2,
                            color: edition.inkAt(72),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ProgressRule(
                  edition: edition,
                  fraction: total == 0 ? 0 : owned / total,
                ),
                const SizedBox(height: 30),
                SectionHeader('Contents', edition: edition, note: 'tap a line'),
                const SizedBox(height: 4),
                for (final line in _lines(magazines, makes, noteCount, nav))
                  _ContentsLine(edition: edition, line: line),
                const SizedBox(height: 30),
                SectionHeader(
                  'Recently added',
                  edition: edition,
                  trailing: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => nav.showCollection(owned: true),
                    child: Text(
                      'see all →',
                      style: AppType.serif(
                        size: 15,
                        italic: true,
                        color: edition.accent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _Rail(
            edition: edition,
            issues: magazines.recentlyAdded,
            onOpen: (id) => nav.push(IssuePage(id)),
          ),
          _Gutter(
            child: Padding(
              padding: const EdgeInsets.only(top: 22),
              child: _SearchLine(
                edition: edition,
                onTap: () => nav.openSheet(BurdaSheet.search),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_Line> _lines(
    MagazineProvider magazines,
    MakeProvider makes,
    int noteCount,
    BurdaNav nav,
  ) => [
    _Line(
      no: '01',
      title: 'Owned',
      sub: 'in the collection',
      value: '${magazines.ownedCount}',
      go: () => nav.showCollection(owned: true),
    ),
    _Line(
      no: '02',
      title: 'Missing',
      sub: 'still to find',
      value: '${magazines.missingCount}',
      go: () => nav.showCollection(owned: false),
    ),
    _Line(
      no: '03',
      title: 'Years',
      sub: '${magazines.completeYearCount} complete',
      value: '${magazines.years.length}',
      go: () => nav.goTab(NavTab.years),
    ),
    _Line(
      no: '04',
      title: 'Notes',
      sub: 'patterns, sizes, ideas',
      value: '$noteCount',
      go: () => nav.push(const NotesPage()),
    ),
    _Line(
      no: '05',
      title: 'Makes',
      sub: '${makes.finishedCount} finished',
      value: '${makes.count}',
      go: () => nav.push(const MakesPage()),
    ),
    _Line(
      no: '06',
      title: 'Rank',
      sub: CollectorRank.hintFor(magazines.ownedCount),
      value: magazines.rank.name,
      go: () => nav.openSheet(BurdaSheet.rank),
    ),
  ];
}

/// One line of the contents table.
class _Line {
  const _Line({
    required this.no,
    required this.title,
    required this.sub,
    required this.value,
    required this.go,
  });

  final String no;
  final String title;
  final String sub;
  final String value;
  final VoidCallback go;
}

/// The gutter the page is set in, which the cover rail alone escapes.
class _Gutter extends StatelessWidget {
  const _Gutter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: kGutter),
    child: child,
  );
}

/// The printer's rule under the masthead: two hairlines 3px apart.
class _DoubleRule extends StatelessWidget {
  const _DoubleRule({required this.edition});

  final Edition edition;

  @override
  Widget build(BuildContext context) {
    final line = Container(height: 1, color: edition.ink);
    return Column(children: [line, const SizedBox(height: 3), line]);
  }
}

class _ContentsLine extends StatelessWidget {
  const _ContentsLine({required this.edition, required this.line});

  final Edition edition;
  final _Line line;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => _row(constraints.maxWidth * 0.42),
    );
  }

  Widget _row(double valueCap) {
    return HairlineRow(
      edition: edition,
      onTap: line.go,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: 34,
            child: Text(
              line.no,
              style: AppType.serif(
                size: 13,
                trackingEm: 0.12,
                tabular: true,
                color: edition.accent,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: '${line.title} ',
                style: AppType.serif(
                  size: 28,
                  weight: 500,
                  trackingEm: -0.01,
                  height: 1,
                  color: edition.ink,
                ),
                children: [
                  TextSpan(
                    text: line.sub,
                    style: AppType.serif(
                      size: 15,
                      italic: true,
                      color: edition.inkAt(60),
                    ),
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          // The design's `auto` column: natural width, so a one-digit count
          // leaves the title almost the whole row. Capped because the rank
          // names are long enough to crowd it, and shrunk rather than clipped
          // when they hit the cap.
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: valueCap),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                line.value,
                style: AppType.serif(
                  size: 26,
                  weight: 300,
                  tabular: true,
                  color: edition.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The strip of covers most recently claimed, which runs to the page edges.
class _Rail extends StatelessWidget {
  const _Rail({
    required this.edition,
    required this.issues,
    required this.onOpen,
  });

  final Edition edition;
  final List<Magazine> issues;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    if (issues.isEmpty) {
      return _Gutter(
        child: Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Text(
            'Nothing yet. The first issue you claim shows up here.',
            style: AppType.serif(
              size: 16,
              italic: true,
              color: edition.inkAt(60),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      // The cover, the gap and the caption, with room for a larger text size.
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(kGutter, 18, kGutter, 8),
        itemCount: issues.length,
        separatorBuilder: (context, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final magazine = issues[index];
          return PressScale(
            scale: 0.96,
            onTap: () => onOpen(magazine.id),
            child: SizedBox(
              width: 86,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 86,
                    height: 118,
                    child: CoverTile(
                      magazine: magazine,
                      edition: edition,
                      numeralSize: 40,
                      depth: CoverDepth.rail,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: Text(
                      'No. ${magazine.issue} · ${magazine.year}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.smallCaps(
                        size: 14,
                        trackingEm: 0.08,
                        height: 1.1,
                        color: edition.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SearchLine extends StatelessWidget {
  const _SearchLine({required this.edition, required this.onTap});

  final Edition edition;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(border: Border.all(color: edition.inkAt(30))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Find an issue, e.g. 2/2024',
                overflow: TextOverflow.ellipsis,
                style: AppType.serif(
                  size: 17,
                  italic: true,
                  color: edition.inkAt(65),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '→',
              style: AppType.serif(size: 22, height: 1, color: edition.ink),
            ),
          ],
        ),
      ),
    );
  }
}
