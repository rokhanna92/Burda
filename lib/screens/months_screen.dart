import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/date_label.dart';
import '../models/magazine.dart';
import '../providers/magazine_provider.dart';
import '../shell/burda_nav.dart';
import '../theme/edition.dart';
import '../theme/season.dart';
import '../theme/typography.dart';
import '../widgets/page_furniture.dart';

/// The year read across itself: twelve months, each holding every year's issue
/// of that month.
///
/// The issue number is the month, so this costs a filter rather than a table.
/// It is grouped under the app's own four weather words, because sewing is
/// planned by weather: linen in May, coats in September.
class MonthsScreen extends StatelessWidget {
  const MonthsScreen({super.key, required this.edition});

  final Edition edition;

  @override
  Widget build(BuildContext context) {
    final magazines = context.watch<MagazineProvider>();
    final nav = BurdaNav.of(context);

    final byMonth = {
      for (var month = 1; month <= kMonths.length; month++)
        month: magazines.magazinesForMonth(month),
    };
    final anything = byMonth.values.any((issues) => issues.isNotEmpty);

    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: BackLink(edition: edition, onTap: nav.back),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: ScreenTitle('Seasons', edition: edition)),
              const SizedBox(width: 10),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'tap a month',
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
          if (!anything)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Text(
                'Nothing filed yet.\n'
                'The months fill as the collection does.',
                textAlign: TextAlign.center,
                style: AppType.serif(
                  size: 19,
                  italic: true,
                  height: 1.4,
                  color: edition.inkAt(60),
                ),
              ),
            )
          else
            for (final season in Season.calendar)
              if (season.months.any((m) => byMonth[m]!.isNotEmpty)) ...[
                const SizedBox(height: 26),
                SectionHeader(
                  season.label,
                  edition: edition,
                  note: season.months
                      .map((month) => kMonths[month - 1])
                      .join(', '),
                ),
                const SizedBox(height: 4),
                for (final month in season.months)
                  if (byMonth[month]!.isNotEmpty)
                    _MonthRow(
                      edition: edition,
                      month: month,
                      issues: byMonth[month]!,
                      onOpen: () => nav.push(MonthPage(month)),
                    ),
              ],
        ],
      ),
    );
  }
}

/// One month, and a mark for every year of it.
class _MonthRow extends StatelessWidget {
  const _MonthRow({
    required this.edition,
    required this.month,
    required this.issues,
    required this.onOpen,
  });

  final Edition edition;
  final int month;
  final List<Magazine> issues;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final owned = issues.where((m) => m.isOwned).length;

    return HairlineRow(
      edition: edition,
      onTap: onOpen,
      verticalPadding: 13,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  kMonths[month - 1],
                  overflow: TextOverflow.ellipsis,
                  style: AppType.serif(size: 26, color: edition.ink),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$owned of ${issues.length}',
                style: AppType.serif(
                  size: 15,
                  italic: true,
                  tabular: true,
                  color: edition.inkAt(65),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          // A strip of years rather than a number: which May is missing reads
          // as a gap in a line, and seventeen fixed marks beside a month name
          // would not fit the gutter.
          Row(
            children: [
              for (final (index, magazine) in issues.indexed) ...[
                if (index > 0) const SizedBox(width: 3),
                Expanded(
                  child: Container(
                    height: 13,
                    decoration: BoxDecoration(
                      color: magazine.isOwned
                          ? edition.accent
                          : Colors.transparent,
                      border: Border.all(color: edition.inkAt(35)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
