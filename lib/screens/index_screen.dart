import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/collector_rank.dart';
import '../models/date_label.dart';
import '../models/endgame.dart';
import '../models/magazine.dart';
import '../models/note_provider.dart';
import '../providers/magazine_provider.dart';
import '../providers/make_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/tonight_provider.dart';
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
    final thisMonth = [
      for (final magazine in magazines.magazinesForMonth(now.month))
        if (magazine.isOwned) magazine,
    ];

    final line = magazines.mainLine;
    final finish = magazines.endgame;
    final percent = line.total == 0
        ? 0
        : (line.owned / line.total * 100).round();

    // Only the two strings change between climbing and finished, never the
    // shape, so the page cannot reflow underneath her as the last issue lands.
    final headline = switch (finish) {
      Finished() => '${line.owned}',
      _ => '$percent%',
    };
    final standfirst = switch (finish) {
      // Endgame.of only returns Finished for a shelf with rows on it, so there
      // is always at least one year to name.
      Finished() =>
        'the complete run\n${line.years.first} to ${line.years.last}',
      _ => 'of the collection\n${line.owned} of ${line.total} issues',
    };

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
                          headline,
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
                          standfirst,
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
                  fraction: line.total == 0 ? 0 : line.owned / line.total,
                ),
                // The one moment the rule is entirely the accent. Taking it
                // away would throw out the picture of the thing being finished.
                if (finish case Finished(:final completedOn?)) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Completed ${dayMonthYear(completedOn)}',
                    style: AppType.smallCaps(
                      size: 13,
                      trackingEm: 0.2,
                      color: edition.accent,
                    ),
                  ),
                ],
                if (finish case LastFew(:final issues)) ...[
                  const SizedBox(height: 30),
                  SectionHeader(
                    switch (issues.length) {
                      1 => 'The last issue',
                      2 => 'The last two',
                      _ => 'The last three',
                    },
                    edition: edition,
                    note: 'then it is finished',
                  ),
                  const SizedBox(height: 4),
                  for (final magazine in issues)
                    _LastFewRow(
                      edition: edition,
                      magazine: magazine,
                      onOpen: () => nav.push(IssuePage(magazine.id)),
                    ),
                ],
                const SizedBox(height: 30),
                // Above the contents table, because the percentage has been 99
                // for weeks and the six numbered lines do not move: this is the
                // only thing on the page that is different tonight than it was
                // last night. A printed contents page puts the editor's pick
                // above the numbered list too.
                _Tonight(edition: edition, now: now),
                const SizedBox(height: 30),
                SectionHeader('Contents', edition: edition, note: 'tap a line'),
                const SizedBox(height: 4),
                for (final entry in _lines(
                  magazines,
                  makes,
                  noteCount,
                  line.missing.length,
                  nav,
                ))
                  _ContentsLine(edition: edition, line: entry),
                // No seventh numbered line: a contents line reading "Lent 0"
                // for months at a time is dead weight. The section answers its
                // question by being here at all, and an index with nothing out
                // of the house is exactly what it was before.
                if (magazines.lent case final lent when lent.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  SectionHeader(
                    'Out of the house',
                    edition: edition,
                    note: 'who has what',
                  ),
                  const SizedBox(height: 4),
                  for (final magazine in lent)
                    _LentLine(
                      edition: edition,
                      magazine: magazine,
                      now: now,
                      go: () => nav.push(IssuePage(magazine.id)),
                    ),
                ],
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
          // What this month has looked like over the years. Only when there is
          // something of it on the shelf: an empty rail is not a section.
          if (thisMonth.isNotEmpty) ...[
            _Gutter(
              child: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: SectionHeader(
                  kMonths[now.month - 1],
                  edition: edition,
                  trailing: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => nav.push(MonthPage(now.month)),
                    child: Text(
                      'every year →',
                      textAlign: TextAlign.end,
                      style: AppType.serif(
                        size: 15,
                        italic: true,
                        color: edition.accent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _Rail(
              edition: edition,
              issues: thisMonth,
              caption: _Rail.year,
              onOpen: (id) => nav.push(IssuePage(id)),
            ),
          ],
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
    int remaining,
    BurdaNav nav,
  ) => [
    _Line(
      no: '01',
      title: 'Owned',
      sub: 'in the collection',
      value: '${magazines.ownedCount}',
      go: () => nav.showCollection(owned: true),
    ),
    // Missing has not gone: it is the Collection screen's second tab and the
    // Years shelf's "still missing" list. At 199 of 201 it had stopped being a
    // number that moves, and the queue is one again.
    _Line(
      no: '02',
      title: 'Queue',
      sub: 'what to make next',
      value: '${makes.queuedCount}',
      go: () => nav.push(const QueuePage()),
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
      sub: CollectorRank.hintFor(magazines.ownedCount, remaining: remaining),
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

/// The evening's card: one issue off the shelf, with a link for another.
///
/// It only reads the deck. Dealing happens at start-up and when she asks for
/// another, never while the page is building, which keeps the index a stateless
/// read of what the app has already decided.
class _Tonight extends StatelessWidget {
  const _Tonight({required this.edition, required this.now});

  final Edition edition;

  /// The index's own clock, so a test can put the app on a given evening.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final tonight = context.watch<TonightProvider>();
    final magazine = tonight.id == null
        ? null
        : context.watch<MagazineProvider>().byId(tonight.id!);
    final nav = BurdaNav.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Tonight',
          edition: edition,
          trailing: magazine == null
              ? null
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () =>
                      context.read<TonightProvider>().another(now: now),
                  child: Text(
                    'another →',
                    textAlign: TextAlign.end,
                    style: AppType.serif(
                      size: 15,
                      italic: true,
                      color: edition.accent,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 16),
        if (magazine == null)
          Text(
            'Nothing to deal yet. The first issue you claim turns up here.',
            style: AppType.serif(
              size: 16,
              italic: true,
              color: edition.inkAt(60),
            ),
          )
        else
          // Keyed on the issue so the card fades up again when she asks for
          // another, rather than swapping the artwork in place.
          CoverIn(
            key: ValueKey(magazine.id),
            child: PressScale(
              scale: 0.98,
              onTap: () => nav.push(IssuePage(magazine.id)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 96,
                    height: 132,
                    child: CoverTile(
                      magazine: magazine,
                      edition: edition,
                      numeralSize: 46,
                      depth: CoverDepth.rail,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No. ${magazine.issue}',
                            style: AppType.serif(
                              size: 30,
                              weight: 500,
                              trackingEm: -0.02,
                              height: 1,
                              color: edition.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${magazine.year}',
                            style: AppType.smallCaps(
                              size: 14,
                              trackingEm: 0.16,
                              color: edition.inkAt(62),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _line(context, magazine.id),
                            style: AppType.serif(
                              size: 17,
                              italic: true,
                              height: 1.3,
                              color: edition.inkAt(72),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// What the card says under the address.
  ///
  /// One sentence. The point of the card is that there is nothing to decide, so
  /// anything longer is the card arguing with itself.
  String _line(BuildContext context, String id) =>
      context.watch<MakeProvider>().madeCountFor(id) > 0
      ? 'You have sewn from this one before.'
      : 'An evening with nothing planned. Take this one down.';
}

/// One of the last few, named by address so she can read it off a spine.
class _LastFewRow extends StatelessWidget {
  const _LastFewRow({
    required this.edition,
    required this.magazine,
    required this.onOpen,
  });

  final Edition edition;
  final Magazine magazine;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final issue = magazine.issue;

    return HairlineRow(
      edition: edition,
      onTap: onOpen,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: 'No. $issue / ${magazine.year} ',
                style: AppType.serif(
                  size: 24,
                  tabular: true,
                  color: edition.ink,
                ),
                children: [
                  // The main line runs a month to an issue, and the month is
                  // what she will read off a spine in a shop.
                  if (issue >= 1 && issue <= kMonths.length)
                    TextSpan(
                      text: kMonths[issue - 1],
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
          Text('→', style: AppType.serif(size: 22, color: edition.ink)),
        ],
      ),
    );
  }
}

/// One issue that is not on the shelf, and who has it.
///
/// Set like a line of the archive on the profile: the address in full size, the
/// name italic beside it, the reading of how long on the right. Longest gone
/// sits at the top, because that is the one she has stopped thinking about.
class _LentLine extends StatelessWidget {
  const _LentLine({
    required this.edition,
    required this.magazine,
    required this.now,
    required this.go,
  });

  final Edition edition;
  final Magazine magazine;
  final DateTime now;
  final VoidCallback go;

  @override
  Widget build(BuildContext context) => HairlineRow(
    edition: edition,
    onTap: go,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              text: 'No. ${magazine.issue} / ${magazine.year} ',
              style: AppType.serif(size: 24, color: edition.ink),
              children: [
                TextSpan(
                  text: 'with ${magazine.lentTo}',
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
        Text(
          elapsed(magazine.lentOn!, now),
          style: AppType.serif(
            size: 16,
            italic: true,
            color: magazine.lentLong(now) ? edition.accent : edition.inkAt(60),
          ),
        ),
      ],
    ),
  );
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
    this.caption = _address,
  });

  final Edition edition;
  final List<Magazine> issues;
  final ValueChanged<String> onOpen;

  /// What is printed under each cover.
  final String Function(Magazine) caption;

  /// "No. 9 · 2019", the address the rest of the app prints.
  static String _address(Magazine magazine) =>
      '${magazine.mark} · ${magazine.year}';

  /// The year alone, for the month rail, where every cover carries the same
  /// number and only the year tells them apart.
  static String year(Magazine magazine) => '${magazine.year}';

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
                      caption(magazine),
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
