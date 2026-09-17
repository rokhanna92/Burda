import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/note.dart';
import '../models/note_provider.dart';

/// Her notes, newest first.
class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  static final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notes = context.watch<NoteProvider>();

    return Scaffold(
      appBar: AppBar(title: const Icon(Icons.edit, color: Colors.white)),
      // A Row, not an Align: a bottom bar child gets loose height
      // constraints, and Align would expand to fill the whole screen.
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 14,
                ),
              ),
              onPressed: () => _showAddNoteModal(context),
              child: const Text(
                'Add Note',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
      body: notes.notes.isEmpty
          ? Center(
              child: Text(
                'Add a new note!',
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              itemCount: notes.notes.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final note = notes.notes[index];
                return Material(
                  color: theme.colorScheme.secondary,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _showNoteDetails(context, note),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  note.title.isEmpty ? 'Note' : note.title,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                _dateFormat.format(note.date),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          if (note.content.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              note.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// The add-note dialog: a title, some content, and save.
Future<void> _showAddNoteModal(BuildContext context) async {
  final provider = context.read<NoteProvider>();
  final messenger = ScaffoldMessenger.of(context);

  final draft = await showDialog<({String title, String content})>(
    context: context,
    builder: (context) => const _AddNoteDialog(),
  );
  if (draft == null) return;

  if (draft.title.isEmpty && draft.content.isEmpty) {
    messenger
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('Add a new note!')));
    return;
  }
  await provider.addNote(title: draft.title, content: draft.content);
  messenger
    ..clearSnackBars()
    ..showSnackBar(const SnackBar(content: Text('Note added!')));
}

/// Owns its text controllers so they outlive the closing animation.
class _AddNoteDialog extends StatefulWidget {
  const _AddNoteDialog();

  @override
  State<_AddNoteDialog> createState() => _AddNoteDialogState();
}

class _AddNoteDialogState extends State<_AddNoteDialog> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _content = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context)
        .pop((title: _title.text.trim(), content: _content.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(
        'Add Note',
        textAlign: TextAlign.center,
        style: theme.textTheme.titleLarge,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _content,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Content'),
          ),
        ],
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.onSurface,
                foregroundColor: Colors.white,
              ),
              onPressed: _save,
              child: const Text('SAVE'),
            ),
          ],
        ),
      ],
    );
  }
}

/// The full note, with the option to delete it.
Future<void> _showNoteDetails(BuildContext context, Note note) async {
  final theme = Theme.of(context);
  final provider = context.read<NoteProvider>();
  final messenger = ScaffoldMessenger.of(context);

  final delete = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        note.title.isEmpty ? 'Note' : note.title,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleLarge,
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              NotesScreen._dateFormat.format(note.date),
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 10),
            Text(note.content, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Delete',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.onSurface,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Close'),
            ),
          ],
        ),
      ],
    ),
  );

  if (delete != true) return;
  await provider.deleteNote(note.id);
  messenger
    ..clearSnackBars()
    ..showSnackBar(const SnackBar(content: Text('Note deleted!')));
}
