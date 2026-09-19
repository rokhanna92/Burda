import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/magazine.dart';
import '../providers/magazine_provider.dart';
import '../services/image_storage_service.dart';
import '../shell/burda_nav.dart';
import '../theme/edition.dart';
import '../theme/typography.dart';
import '../widgets/page_furniture.dart';
import '../widgets/sheet_scaffold.dart';

/// Filing an issue by hand: pick a number, pick a year, in it goes.
class AddSheet extends StatefulWidget {
  const AddSheet({super.key, required this.edition, this.today});

  final Edition edition;
  final DateTime? today;

  /// The earliest year that can be filed.
  static const int firstYear = 2000;

  /// Past this, issues go in one at a time rather than twelve at a time.
  static const int lastFullYear = 2025;

  /// How many issues a year holds.
  static const int issuesPerYear = 12;

  @override
  State<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<AddSheet> {
  late int _year = (widget.today ?? DateTime.now()).year;
  int _issue = 1;
  String? _coverPath;
  bool _busy = false;

  int get _latestYear => (widget.today ?? DateTime.now()).year + 1;

  Magazine _build(int issue, {required bool owned}) => Magazine(
    id: '$issue-$_year',
    title: '$issue/$_year',
    year: _year,
    image: _coverPath ?? 'covers/$issue-$_year.jpg',
    isOwned: owned,
    dateAdded: owned ? DateTime.now() : null,
  );

  Future<void> _pickCover() async {
    if (_busy) return;
    setState(() => _busy = true);
    final nav = BurdaNav.of(context);
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) {
        nav.showToast('No photo chosen');
        return;
      }
      final path = await ImageStorageService.saveCover(
        magazineId: '$_issue-$_year',
        sourcePath: picked.path,
      );
      if (mounted) setState(() => _coverPath = path);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addOne() async {
    final nav = BurdaNav.of(context);
    final magazines = context.read<MagazineProvider>();

    if (magazines.byId('$_issue-$_year') != null) {
      nav.showToast('That issue is already filed');
      return;
    }
    if (magazines.magazinesForYear(_year).length >= AddSheet.issuesPerYear) {
      nav.showToast('$_year already has ${AddSheet.issuesPerYear} issues');
      return;
    }

    await magazines.addMagazine(_build(_issue, owned: true));
    nav.closeSheet();
    nav.showToast('No. $_issue / $_year added to the collection');
  }

  Future<void> _addWholeYear() async {
    final nav = BurdaNav.of(context);
    final magazines = context.read<MagazineProvider>();

    if (_year > AddSheet.lastFullYear) {
      nav.showToast('After ${AddSheet.lastFullYear} issues go in one by one');
      return;
    }

    final have = magazines.magazinesForYear(_year).map((m) => m.issue).toSet();
    final missing = [
      for (var issue = 1; issue <= AddSheet.issuesPerYear; issue++)
        if (!have.contains(issue)) issue,
    ];
    if (missing.isEmpty) {
      nav.showToast('$_year is already complete');
      return;
    }

    for (final issue in missing) {
      await magazines.addMagazine(_build(issue, owned: false));
    }
    nav.closeSheet();
    nav.showToast('$_year filed with ${missing.length} issues');
  }

  @override
  Widget build(BuildContext context) {
    final edition = widget.edition;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeading(
          edition: edition,
          eyebrow: 'New entry',
          title: 'Add an issue',
        ),
        const SizedBox(height: 22),
        _FieldLabel('Issue', edition: edition),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 6,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 52 / 42,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var issue = 1; issue <= AddSheet.issuesPerYear; issue++)
              PressScale(
                scale: 0.93,
                onTap: () => setState(() => _issue = issue),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _issue == issue ? edition.ink : Colors.transparent,
                    border: Border.all(color: edition.inkAt(35)),
                  ),
                  child: Text(
                    '$issue',
                    style: AppType.serif(
                      size: 18,
                      tabular: true,
                      color: _issue == issue ? edition.paper : edition.ink,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        _FieldLabel('Year', edition: edition),
        const SizedBox(height: 10),
        _YearStepper(
          edition: edition,
          year: _year,
          onDown: _year > AddSheet.firstYear
              ? () => setState(() => _year--)
              : null,
          onUp: _year < _latestYear ? () => setState(() => _year++) : null,
        ),
        const SizedBox(height: 14),
        _CoverPicker(
          edition: edition,
          chosen: _coverPath != null,
          onTap: _busy ? null : _pickCover,
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              flex: 14,
              child: BurdaButton(
                edition: edition,
                label: 'Add No. $_issue / $_year',
                filled: true,
                onTap: _addOne,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 10,
              child: BurdaButton(
                edition: edition,
                label: 'Whole year',
                onTap: _addWholeYear,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {required this.edition});

  final String text;
  final Edition edition;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppType.smallCaps(size: 13, trackingEm: 0.18, color: edition.ink),
  );
}

class _YearStepper extends StatelessWidget {
  const _YearStepper({
    required this.edition,
    required this.year,
    required this.onDown,
    required this.onUp,
  });

  final Edition edition;
  final int year;
  final VoidCallback? onDown;
  final VoidCallback? onUp;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(border: Border.all(color: edition.inkAt(35))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _step('−', onDown),
          Text(
            '$year',
            style: AppType.serif(
              size: 32,
              weight: 300,
              tabular: true,
              color: edition.ink,
            ),
          ),
          _step('+', onUp),
        ],
      ),
    );
  }

  Widget _step(String glyph, VoidCallback? onTap) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: SizedBox(
      width: 56,
      height: 52,
      child: Center(
        child: Text(
          glyph,
          style: AppType.serif(
            size: 28,
            color: onTap == null ? edition.inkAt(30) : edition.ink,
          ),
        ),
      ),
    ),
  );
}

class _CoverPicker extends StatelessWidget {
  const _CoverPicker({
    required this.edition,
    required this.chosen,
    required this.onTap,
  });

  final Edition edition;
  final bool chosen;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: CustomPaint(
        painter: DashedBorder(colour: edition.inkAt(45)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            chosen ? 'Cover photo chosen' : 'Choose a cover photo (optional)',
            textAlign: TextAlign.center,
            style: AppType.serif(
              size: 15,
              italic: true,
              color: chosen ? edition.accent : edition.ink,
            ),
          ),
        ),
      ),
    );
  }
}
