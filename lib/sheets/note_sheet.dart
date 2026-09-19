import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/date_label.dart';
import '../models/note_provider.dart';
import '../shell/burda_nav.dart';
import '../theme/edition.dart';
import '../theme/typography.dart';
import '../widgets/page_furniture.dart';

/// Writing a note: a title, a body, and today's date standing in for a heading.
class NoteSheet extends StatefulWidget {
  const NoteSheet({super.key, required this.edition, this.today});

  final Edition edition;

  /// Overridable so a test is not at the mercy of the calendar.
  final DateTime? today;

  @override
  State<NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<NoteSheet> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nav = BurdaNav.of(context);
    final title = _title.text.trim();
    final body = _body.text.trim();

    if (title.isEmpty && body.isEmpty) {
      nav.showToast('Write something first');
      return;
    }

    await context.read<NoteProvider>().addNote(title: title, content: body);
    if (!mounted) return;
    nav.closeSheet();
    nav.showToast('Note added');
  }

  @override
  Widget build(BuildContext context) {
    final edition = widget.edition;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          dayMonthYear(widget.today ?? DateTime.now()),
          style: AppType.smallCaps(
            size: 13,
            trackingEm: 0.22,
            color: edition.accent,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _title,
          autofocus: true,
          style: AppType.serif(size: 34, weight: 500, color: edition.ink),
          cursorColor: edition.accent,
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 6),
            hintText: 'Title',
            hintStyle: AppType.serif(
              size: 34,
              weight: 500,
              color: edition.inkAt(35),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: edition.inkAt(18))),
          ),
          child: TextField(
            controller: _body,
            minLines: 5,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            style: AppType.serif(size: 18, height: 1.45, color: edition.ink),
            cursorColor: edition.accent,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              hintText: 'Write it down before it slips away…',
              hintStyle: AppType.serif(
                size: 18,
                height: 1.45,
                color: edition.inkAt(35),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        BurdaButton(
          edition: edition,
          label: 'Save note',
          filled: true,
          onTap: _save,
        ),
      ],
    );
  }
}
