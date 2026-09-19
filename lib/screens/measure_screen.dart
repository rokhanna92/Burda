import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/date_label.dart';
import '../models/measurements.dart';
import '../models/size_chart.dart';
import '../providers/measure_provider.dart';
import '../shell/burda_nav.dart';
import '../theme/edition.dart';
import '../theme/typography.dart';
import '../widgets/page_furniture.dart';

/// Her measurements, the size they come to, and the table they come from.
///
/// Boring, unglamorous, and opened every time she cuts. The size is set in the
/// index's own numeral, because it is the number this page is for.
class MeasureScreen extends StatelessWidget {
  const MeasureScreen({super.key, required this.edition});

  final Edition edition;

  /// The line beside the big number.
  static String _note(Measurements measure) {
    if (measure.chosenSize != null) return 'your Burda size\nset by you';
    final top = measure.topSize;
    final skirt = measure.skirtSize;
    if (top != null && skirt != null && top != skirt) {
      return 'your Burda size\n$top for tops, $skirt for skirts';
    }
    return 'your Burda size\nfrom the chart';
  }

  @override
  Widget build(BuildContext context) {
    final measure = context.watch<MeasureProvider>().measurements;
    final nav = BurdaNav.of(context);
    final size = measure.size;
    final row = measure.row;
    final skirt = measure.skirtSize;

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
          // Measurements go stale, so the day they were taken is the first
          // thing the page says.
          Eyebrow(
            measure.takenOn == null
                ? 'Not taken yet'
                : 'Taken ${dayMonthYear(measure.takenOn!)}',
            edition: edition,
          ),
          const SizedBox(height: 4),
          ScreenTitle('Measurements', edition: edition),
          const SizedBox(height: 22),
          if (size == null)
            Text(
              'Take your measurements and the size follows.',
              style: AppType.serif(
                size: 19,
                italic: true,
                color: edition.inkAt(70),
              ),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 210),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      skirt != null && skirt != size
                          ? '$size / $skirt'
                          : '$size',
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
                      _note(measure),
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
            if (row != null) ...[
              const SizedBox(height: 10),
              Text(
                'German ${row.size} · UK ${row.uk} · US ${row.us}',
                style: AppType.smallCaps(
                  size: 13,
                  trackingEm: 0.2,
                  color: edition.inkAt(55),
                ),
              ),
            ],
            if (size >= 44) ...[
              const SizedBox(height: 6),
              Text(
                'Burda Style Plus prints this size.',
                style: AppType.serif(
                  size: 15,
                  italic: true,
                  color: edition.inkAt(60),
                ),
              ),
            ],
          ],
          if (measure.offChart) ...[
            const SizedBox(height: 10),
            Text(
              'Your bust is off the chart. '
              "Burda's table runs from ${centimetres(SizeChart.rows.first.bust)}"
              ' to ${centimetres(SizeChart.rows.last.bust)} cm.',
              style: AppType.serif(size: 17, italic: true, color: edition.ink),
            ),
          ],
          const SizedBox(height: 10),
          // Under the number, because that is the claim it qualifies, rather
          // than at the foot of the page where she has stopped reading.
          Text(
            'A guide, not a rule. The table in the issue you are cutting from '
            'is the one that counts.',
            style: AppType.serif(
              size: 15,
              italic: true,
              height: 1.35,
              color: edition.inkAt(55),
            ),
          ),
          const SizedBox(height: 30),
          SectionHeader(
            'Your numbers',
            edition: edition,
            note: 'tap to take them again',
          ),
          const SizedBox(height: 4),
          for (final (name, hint, value) in [
            ('Bust', 'the fullest part', measure.bust),
            ('Waist', 'at the narrowest', measure.waist),
            ('Hip', 'the fullest part, standing', measure.hip),
            ('Back length', 'nape to waist', measure.backWaist),
            ('Height', 'without shoes', measure.height),
          ])
            _NumberRow(
              edition: edition,
              name: name,
              hint: hint,
              value: value,
              onTap: () => nav.openSheet(BurdaSheet.measure),
            ),
          const SizedBox(height: 18),
          BurdaButton(
            edition: edition,
            label: measure.isTaken
                ? 'Take them again'
                : 'Take your measurements',
            filled: !measure.isTaken,
            onTap: () => nav.openSheet(BurdaSheet.measure),
          ),
          const SizedBox(height: 34),
          SectionHeader(
            'The chart',
            edition: edition,
            note: 'your sizes are marked',
          ),
          const SizedBox(height: 10),
          _Chart(edition: edition, measure: measure),
          const SizedBox(height: 30),
          SectionHeader(
            'The runs',
            edition: edition,
            note: measure.height == null
                ? 'the same body, a different length'
                : '${centimetres(measure.height!)} cm puts you in '
                      '${measure.run.label}',
          ),
          for (final run in SizeRun.values)
            HairlineRow(
              edition: edition,
              verticalPadding: 12,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: '${run.label} ',
                        style: AppType.serif(size: 20, color: edition.ink),
                        children: [
                          TextSpan(
                            text: run.note,
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
                  if (size != null) ...[
                    const SizedBox(width: 10),
                    Text(
                      run.numberFor(size),
                      style: AppType.serif(
                        size: 22,
                        weight: 300,
                        tabular: true,
                        color: run == measure.run
                            ? edition.accent
                            : edition.inkAt(60),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 30),
          SectionHeader('Ease', edition: edition, note: 'at the bust'),
          for (final band in SizeChart.ease)
            HairlineRow(
              edition: edition,
              verticalPadding: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      band.label,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.serif(size: 20, color: edition.ink),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      band.range,
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.serif(
                        size: 15,
                        italic: true,
                        color: edition.inkAt(60),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Text(
            'For a blouse or a dress. A jacket takes about 2 cm more, a coat '
            'about 5.',
            style: AppType.serif(
              size: 15,
              italic: true,
              height: 1.35,
              color: edition.inkAt(55),
            ),
          ),
        ],
      ),
    );
  }
}

/// One measured number, or the fact that it is not taken.
class _NumberRow extends StatelessWidget {
  const _NumberRow({
    required this.edition,
    required this.name,
    required this.hint,
    required this.value,
    required this.onTap,
  });

  final Edition edition;
  final String name;
  final String hint;
  final double? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => HairlineRow(
    edition: edition,
    onTap: onTap,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              text: '$name ',
              style: AppType.serif(size: 24, color: edition.ink),
              children: [
                TextSpan(
                  text: hint,
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
        if (value == null)
          Text(
            'not set',
            style: AppType.serif(
              size: 15,
              italic: true,
              color: edition.inkAt(60),
            ),
          )
        else
          Text.rich(
            TextSpan(
              text: centimetres(value!),
              style: AppType.serif(
                size: 26,
                weight: 300,
                tabular: true,
                color: edition.ink,
              ),
              children: [
                TextSpan(
                  text: ' cm',
                  style: AppType.serif(
                    size: 15,
                    italic: true,
                    color: edition.inkAt(60),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Burda's table, with her rows picked out.
///
/// The marking needs no legend: her size's row is filled with the tint a cover
/// sits in, and the one cell that chose that row is printed in the accent.
class _Chart extends StatelessWidget {
  const _Chart({required this.edition, required this.measure});

  final Edition edition;
  final Measurements measure;

  @override
  Widget build(BuildContext context) {
    final top = measure.topSize;
    final skirt = measure.skirtSize;
    final chose = measure.chosenSize != null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              for (final (width, label) in [
                (54.0, 'Size'),
                (null, 'Bust'),
                (null, 'Waist'),
                (null, 'Hip'),
                (null, 'Back'),
              ])
                _cell(
                  width,
                  Text(
                    label,
                    textAlign: width == null ? TextAlign.end : TextAlign.start,
                    style: AppType.smallCaps(
                      size: 11,
                      trackingEm: 0.16,
                      color: edition.inkAt(55),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Heavier than a list rule, because a table head is.
        Container(height: 1, color: edition.inkAt(35)),
        for (final row in SizeChart.rows)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: row.size == top || row.size == skirt
                  ? edition.tint
                  : Colors.transparent,
              border: Border(bottom: BorderSide(color: edition.inkAt(14))),
            ),
            child: Row(
              children: [
                _cell(
                  54,
                  Text(
                    '${row.size}',
                    style: AppType.serif(
                      size: 15,
                      weight: row.size == top || row.size == skirt ? 500 : 400,
                      tabular: true,
                      color: edition.ink,
                    ),
                  ),
                ),
                _number(row.bust, chose: chose, picked: row.size == top),
                _number(row.waist, chose: chose, picked: false),
                _number(row.hip, chose: chose, picked: row.size == skirt),
                _number(row.backWaist, chose: chose, picked: false),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(double? width, Widget child) => width == null
      ? Expanded(child: child)
      : SizedBox(width: width, child: child);

  /// A measurement cell, in the accent when it is the one that chose the row.
  Widget _number(double value, {required bool chose, required bool picked}) =>
      Expanded(
        child: Text(
          centimetres(value),
          textAlign: TextAlign.end,
          style: AppType.serif(
            size: 15,
            tabular: true,
            // Nothing is in the accent when she picked the size herself: no
            // measurement chose it.
            color: picked && !chose ? edition.accent : edition.inkAt(75),
          ),
        ),
      );
}
