import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/measurements.dart';
import '../models/size_chart.dart';
import '../providers/measure_provider.dart';
import '../shell/burda_nav.dart';
import '../theme/edition.dart';
import '../theme/typography.dart';
import '../widgets/page_furniture.dart';
import '../widgets/sheet_scaffold.dart';

/// Taking the measurements: six numbers and a save.
///
/// All of them at once, because that is how a tape measure is used. An empty
/// box is an answer too: it means she did not measure that, and the number that
/// was there stops being hers.
class MeasureSheet extends StatefulWidget {
  const MeasureSheet({super.key, required this.edition, this.today});

  final Edition edition;

  /// Overridable so a test is not at the mercy of the calendar.
  final DateTime? today;

  @override
  State<MeasureSheet> createState() => _MeasureSheetState();
}

class _MeasureSheetState extends State<MeasureSheet> {
  late final Measurements _taken = context.read<MeasureProvider>().measurements;

  late final Map<String, TextEditingController> _fields = {
    'bust': TextEditingController(text: _start(_taken.bust)),
    'waist': TextEditingController(text: _start(_taken.waist)),
    'hip': TextEditingController(text: _start(_taken.hip)),
    'back': TextEditingController(text: _start(_taken.backWaist)),
    'height': TextEditingController(text: _start(_taken.height)),
    'size': TextEditingController(
      text: _taken.chosenSize == null ? '' : '${_taken.chosenSize}',
    ),
  };

  static String _start(double? value) =>
      value == null ? '' : centimetres(value);

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  /// A comma is what this keyboard gives, and it means what a point means.
  double? _read(String key) {
    final text = _fields[key]!.text.trim().replaceAll(',', '.');
    return text.isEmpty ? null : double.tryParse(text);
  }

  Future<void> _save() async {
    final nav = BurdaNav.of(context);
    final taken = Measurements(
      bust: _read('bust'),
      waist: _read('waist'),
      hip: _read('hip'),
      backWaist: _read('back'),
      height: _read('height'),
      chosenSize: int.tryParse(_fields['size']!.text.trim()),
    );

    if (!taken.isTaken && taken.chosenSize == null) {
      nav.showToast('Write a number first');
      return;
    }

    await context.read<MeasureProvider>().save(taken, now: widget.today);
    if (!mounted) return;
    nav.closeSheet();
    nav.showToast('Measurements saved');
  }

  @override
  Widget build(BuildContext context) {
    final edition = widget.edition;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeading(
          edition: edition,
          eyebrow: 'In centimetres',
          title: 'Your measurements',
        ),
        const SizedBox(height: 22),
        for (final (key, label) in [
          ('bust', 'Bust'),
          ('waist', 'Waist'),
          ('hip', 'Hip'),
          ('back', 'Back length'),
          ('height', 'Height'),
        ])
          _MeasureField(
            edition: edition,
            label: label,
            controller: _fields[key]!,
            hint: 'cm',
          ),
        const SizedBox(height: 10),
        _MeasureField(
          edition: edition,
          label: 'Your size',
          controller: _fields['size']!,
          hint: "leave it empty to take the chart's word",
          decimal: false,
        ),
        const SizedBox(height: 22),
        BurdaButton(
          edition: edition,
          label: 'Save measurements',
          filled: true,
          onTap: _save,
        ),
      ],
    );
  }
}

/// A name on the left and a number on the right, on one rule.
class _MeasureField extends StatelessWidget {
  const _MeasureField({
    required this.edition,
    required this.label,
    required this.controller,
    required this.hint,
    this.decimal = true,
  });

  final Edition edition;
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool decimal;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: edition.inkAt(18))),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: AppType.smallCaps(
            size: 13,
            trackingEm: 0.18,
            color: edition.ink,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: TextField(
            controller: controller,
            textAlign: TextAlign.end,
            keyboardType: TextInputType.numberWithOptions(decimal: decimal),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                decimal ? RegExp(r'[0-9.,]') : RegExp('[0-9]'),
              ),
            ],
            style: AppType.serif(size: 22, tabular: true, color: edition.ink),
            cursorColor: edition.accent,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              hintText: hint,
              hintStyle: AppType.serif(
                size: 15,
                italic: true,
                color: edition.inkAt(35),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
