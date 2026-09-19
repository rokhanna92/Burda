import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/date_label.dart';
import '../providers/theme_provider.dart';
import '../theme/edition.dart';
import '../theme/typography.dart';
import '../widgets/page_furniture.dart';

/// The index: the collection's front page.
///
/// Reads as the contents page of a magazine, which is why the title is set in
/// the script face and the stats sit under a printer's double rule.
class IndexScreen extends StatelessWidget {
  const IndexScreen({super.key, required this.edition, this.today});

  final Edition edition;

  /// Overridable so a test is not at the mercy of the calendar.
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final editionName = context.select<ThemeProvider, String>(
      (theme) => theme.edition.name,
    );
    final now = today ?? DateTime.now();

    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Eyebrow("The collector's index", edition: edition, centred: true),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 0),
            child: Text(
              'Burda Style',
              textAlign: TextAlign.center,
              style: AppType.logo(size: 66, height: 1.3, color: edition.accent),
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
        ],
      ),
    );
  }
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
