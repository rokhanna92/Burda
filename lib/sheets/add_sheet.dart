import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/magazine.dart';
import '../models/series.dart';
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
  Series _series = Series.style;
  String? _coverPath;
  bool _busy = false;

  int get _latestYear => (widget.today ?? DateTime.now()).year + 1;

  /// The largest number a shelf will file in one year.
  ///
  /// No magazine has printed a hundredth number in a year, and the stepper's
  /// numeral has to fit the box.
  static const int _openCeiling = 99;

  String get _id => Magazine.idFor(series: _series, issue: _issue, year: _year);

  Magazine _build(int issue, {required bool owned}) {
    final id = Magazine.idFor(series: _series, issue: issue, year: _year);
    return Magazine(
      id: id,
      title: '$issue/$_year',
      year: _year,
      issue: issue,
      series: _series,
      image: _coverPath ?? (_series.bundledCovers ? 'covers/$id.jpg' : ''),
      isOwned: owned,
      dateAdded: owned ? DateTime.now() : null,
    );
  }

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
        magazineId: _id,
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

    if (magazines.byId(_id) != null) {
      nav.showToast('That issue is already filed');
      return;
    }
    if (_series.perYear case final perYear?) {
      if (magazines.magazinesForYear(_year, series: _series).length >=
          perYear) {
        nav.showToast('$_year already has $perYear issues');
        return;
      }
    }

    await magazines.addMagazine(_build(_issue, owned: true));
    nav.closeSheet();
    nav.showToast('${_series.markOf(_issue)} / $_year added to the collection');
  }

  Future<void> _addWholeYear() async {
    final nav = BurdaNav.of(context);
    final magazines = context.read<MagazineProvider>();

    if (_year > AddSheet.lastFullYear) {
      nav.showToast('After ${AddSheet.lastFullYear} issues go in one by one');
      return;
    }

    final have = magazines
        .magazinesForYear(_year, series: _series)
        .map((m) => m.issue)
        .toSet();
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
        // The one thing here that is always drawn, shelves or no shelves: it
        // is the only door to a second one.
        _FieldLabel('Shelf', edition: edition),
        const SizedBox(height: 10),
        _ShelfPicker(
          edition: edition,
          picked: _series,
          onPick: (series) => setState(() {
            _series = series;
            // A 17 chosen under Special must not file itself as a seventeenth
            // Burda Style.
            if (series.perYear case final perYear?) {
              if (_issue > perYear) _issue = perYear;
            }
            if (_year < series.firstYear) _year = series.firstYear;
          }),
        ),
        const SizedBox(height: 20),
        _FieldLabel('Issue', edition: edition),
        const SizedBox(height: 10),
        if (_series.perYear case final perYear?)
          GridView.count(
            crossAxisCount: 6,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 52 / 42,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var issue = 1; issue <= perYear; issue++)
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
          )
        else
          _Stepper(
            edition: edition,
            value: '$_issue',
            onDown: _issue > 1 ? () => setState(() => _issue--) : null,
            onUp: _issue < _openCeiling ? () => setState(() => _issue++) : null,
          ),
        const SizedBox(height: 20),
        _FieldLabel('Year', edition: edition),
        const SizedBox(height: 10),
        _Stepper(
          edition: edition,
          value: '$_year',
          onDown: _year > _series.firstYear
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
                label: 'Add ${_series.markOf(_issue)} / $_year',
                filled: true,
                onTap: _addOne,
              ),
            ),
            // A shelf nobody can count has no whole year to fill.
            if (_series.counted) ...[
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

/// Which shelf the issue goes on.
class _ShelfPicker extends StatelessWidget {
  const _ShelfPicker({
    required this.edition,
    required this.picked,
    required this.onPick,
  });

  final Edition edition;
  final Series picked;
  final ValueChanged<Series> onPick;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final series in Series.values) ...[
        if (series != Series.values.first) const SizedBox(width: 8),
        Expanded(
          child: PressScale(
            scale: 0.93,
            onTap: () => onPick(series),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 42,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: series == picked ? edition.ink : Colors.transparent,
                border: Border.all(color: edition.inkAt(35)),
              ),
              // Scaled down rather than clipped: "Special" cannot be allowed
              // to crowd a narrow phone.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  series.shelf,
                  style: AppType.smallCaps(
                    size: 13,
                    trackingEm: 0.12,
                    color: series == picked ? edition.paper : edition.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ],
  );
}

/// A number with a side to hold on each end.
///
/// Holding repeats, because the year now reaches back to 1950 and nobody is
/// tapping sixty times to get there.
class _Stepper extends StatefulWidget {
  const _Stepper({
    required this.edition,
    required this.value,
    required this.onDown,
    required this.onUp,
  });

  final Edition edition;
  final String value;
  final VoidCallback? onDown;
  final VoidCallback? onUp;

  @override
  State<_Stepper> createState() => _StepperState();
}

class _StepperState extends State<_Stepper> {
  Timer? _repeat;

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  /// Steps every 90ms while a side is held, and stops itself the moment the end
  /// of the range takes the callback away.
  void _start({required bool down}) {
    _repeat?.cancel();
    _repeat = Timer.periodic(const Duration(milliseconds: 90), (timer) {
      final step = down ? widget.onDown : widget.onUp;
      if (step == null) return timer.cancel();
      step();
    });
  }

  void _stop() => _repeat?.cancel();

  @override
  Widget build(BuildContext context) {
    final edition = widget.edition;

    return DecoratedBox(
      decoration: BoxDecoration(border: Border.all(color: edition.inkAt(35))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _step('−', widget.onDown, down: true),
          Text(
            widget.value,
            style: AppType.serif(
              size: 32,
              weight: 300,
              tabular: true,
              color: edition.ink,
            ),
          ),
          _step('+', widget.onUp, down: false),
        ],
      ),
    );
  }

  Widget _step(String glyph, VoidCallback? onTap, {required bool down}) =>
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onTap == null ? null : () => _start(down: down),
        onLongPressEnd: (_) => _stop(),
        onLongPressCancel: _stop,
        child: SizedBox(
          width: 56,
          height: 52,
          child: Center(
            child: Text(
              glyph,
              style: AppType.serif(
                size: 28,
                color: onTap == null
                    ? widget.edition.inkAt(30)
                    : widget.edition.ink,
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
