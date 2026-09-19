import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/date_label.dart';
import '../models/note.dart';
import '../models/note_provider.dart';
import '../shell/burda_nav.dart';
import '../theme/edition.dart';
import '../theme/typography.dart';
import '../widgets/page_furniture.dart';

/// Patterns, sizes and ideas, kept loose rather than pinned to an issue.
class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key, required this.edition});

  final Edition edition;

  @override
  Widget build(BuildContext context) {
    final notes = context.watch<NoteProvider>().notes;
    final nav = BurdaNav.of(context);

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
              ScreenTitle('Notes', edition: edition),
              BurdaButton(
                edition: edition,
                label: '+ New note',
                filled: true,
                size: 15,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                pressScale: 0.96,
                onTap: () => nav.openSheet(BurdaSheet.note),
              ),
            ],
          ),
          if (notes.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Text(
                'A blank page. Write the first line.',
                textAlign: TextAlign.center,
                style: AppType.serif(
                  size: 19,
                  italic: true,
                  color: edition.inkAt(60),
                ),
              ),
            )
          else ...[
            const SizedBox(height: 14),
            for (final note in notes)
              _NoteEntry(key: ValueKey(note.id), edition: edition, note: note),
          ],
        ],
      ),
    );
  }
}

class _NoteEntry extends StatelessWidget {
  const _NoteEntry({super.key, required this.edition, required this.note});

  final Edition edition;
  final Note note;

  Future<void> _remove(BuildContext context) async {
    final nav = BurdaNav.of(context);
    await context.read<NoteProvider>().deleteNote(note.id);
    nav.showToast('Note deleted');
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.ease,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - t)),
          child: child,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: edition.inkAt(14))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dayMonthYear(note.date),
                    style: AppType.smallCaps(
                      size: 12,
                      trackingEm: 0.18,
                      color: edition.accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    note.title.isEmpty ? 'Note' : note.title,
                    style: AppType.serif(
                      size: 26,
                      weight: 500,
                      height: 1.1,
                      color: edition.ink,
                    ),
                  ),
                  if (note.content.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      note.content,
                      style: AppType.serif(
                        size: 17,
                        height: 1.4,
                        color: edition.inkAt(78),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _remove(context),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  '×',
                  style: AppType.serif(
                    size: 24,
                    height: 1,
                    color: edition.inkAt(50),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
