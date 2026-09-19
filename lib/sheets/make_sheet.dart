import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/garment_tag.dart';
import '../models/magazine.dart';
import '../models/make.dart';
import '../providers/magazine_provider.dart';
import '../providers/make_provider.dart';
import '../providers/measure_provider.dart';
import '../shell/burda_nav.dart';
import '../theme/edition.dart';
import '../theme/typography.dart';
import '../widgets/page_furniture.dart';
import '../widgets/sheet_scaffold.dart';
import '../widgets/tag_chips.dart';

/// Writing down what a make is: the garment, the pattern, the size, the cloth.
///
/// No status control here. A new make is born queued, and on save the sheet
/// closes and its own page opens, which is where the stages are: you make a
/// thing and you land on it.
class MakeSheet extends StatefulWidget {
  const MakeSheet({
    super.key,
    required this.edition,
    this.make,
    this.magazineId,
  });

  final Edition edition;

  /// The make being edited, or null to start one.
  final Make? make;

  /// The issue it comes out of, when it is started from one.
  final String? magazineId;

  @override
  State<MakeSheet> createState() => _MakeSheetState();
}

class _MakeSheetState extends State<MakeSheet> {
  late final TextEditingController _pattern = TextEditingController(
    text: widget.make?.patternNo ?? '',
  );
  late final TextEditingController _size = TextEditingController(
    text: widget.make?.size ?? '',
  );
  late final TextEditingController _fabric = TextEditingController(
    text: widget.make?.fabric ?? '',
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.make?.notes ?? '',
  );

  late GarmentTag? _garment = widget.make?.garment;

  @override
  void dispose() {
    _pattern.dispose();
    _size.dispose();
    _fabric.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nav = BurdaNav.of(context);
    final makes = context.read<MakeProvider>();
    final pattern = _pattern.text.trim();
    final size = _size.text.trim();
    final fabric = _fabric.text.trim();
    final notes = _notes.text.trim();

    if (_garment == null && pattern.isEmpty) {
      nav.showToast('Say what you are making first');
      return;
    }

    if (widget.make case final existing?) {
      await makes.updateMake(
        existing.copyWith(
          patternNo: pattern,
          garment: _garment,
          clearGarment: _garment == null,
          size: size,
          fabric: fabric,
          notes: notes,
        ),
      );
      nav.closeSheet();
      nav.showToast('Make saved');
      return;
    }

    final made = await makes.addMake(
      magazineId: widget.magazineId,
      patternNo: pattern,
      garment: _garment,
      size: size,
      fabric: fabric,
      notes: notes,
    );
    nav.closeSheet();
    nav.push(MakePage(made.id));
    nav.showToast('${made.name} added to the journal');
  }

  @override
  Widget build(BuildContext context) {
    final edition = widget.edition;
    final editing = widget.make != null;
    final magazineId = widget.make?.magazineId ?? widget.magazineId;
    final hint = _garment == null
        ? null
        : context.read<MeasureProvider>().sizeFor(_garment!);
    final magazine = magazineId == null
        ? null
        : context.select<MagazineProvider, Magazine?>(
            (magazines) => magazines.byId(magazineId),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeading(
          edition: edition,
          eyebrow: 'The journal',
          title: editing ? 'Edit this make' : 'Start a make',
        ),
        if (magazine != null) ...[
          const SizedBox(height: 6),
          Text(
            'From No. ${magazine.issue} / ${magazine.year}',
            style: AppType.serif(
              size: 15,
              italic: true,
              color: edition.inkAt(65),
            ),
          ),
        ],
        const SizedBox(height: 22),
        _FieldLabel('Garment', edition: edition),
        const SizedBox(height: 10),
        TagChips(
          edition: edition,
          tags: GarmentTag.values,
          picked: {?_garment},
          onToggle: (tag) =>
              setState(() => _garment = _garment == tag ? null : tag),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Field(
                edition: edition,
                label: 'Pattern',
                controller: _pattern,
                hint: 'e.g. 118',
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _Field(
                edition: edition,
                label: 'Size',
                controller: _size,
                // Her own size when the app knows it, so the commonest answer
                // is already in front of her. A hint, never a value: what she
                // cut is a fact about this garment and half the time the
                // pattern's own table beat the chart.
                hint: hint == null ? 'e.g. 38' : 'e.g. $hint',
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _Field(
          edition: edition,
          label: 'Fabric',
          controller: _fabric,
          hint: 'e.g. charcoal linen',
        ),
        const SizedBox(height: 18),
        _Field(
          edition: edition,
          label: 'Notes',
          controller: _notes,
          hint: 'Changes, fit, what you would do again…',
          minLines: 3,
        ),
        const SizedBox(height: 22),
        BurdaButton(
          edition: edition,
          label: 'Save make',
          filled: true,
          onTap: _save,
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

/// A label over a line to write on, the note sheet's field.
class _Field extends StatelessWidget {
  const _Field({
    required this.edition,
    required this.label,
    required this.controller,
    required this.hint,
    this.minLines = 1,
  });

  final Edition edition;
  final String label;
  final TextEditingController controller;
  final String hint;
  final int minLines;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _FieldLabel(label, edition: edition),
      Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: edition.inkAt(18))),
        ),
        child: TextField(
          controller: controller,
          minLines: minLines,
          maxLines: minLines > 1 ? null : 1,
          keyboardType: minLines > 1
              ? TextInputType.multiline
              : TextInputType.text,
          style: AppType.serif(size: 18, height: 1.45, color: edition.ink),
          cursorColor: edition.accent,
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            hintText: hint,
            hintStyle: AppType.serif(
              size: 18,
              height: 1.45,
              color: edition.inkAt(35),
            ),
          ),
        ),
      ),
    ],
  );
}
