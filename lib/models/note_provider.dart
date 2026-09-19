import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../services/database_service.dart';
import 'note.dart';

/// Notes list state. Newest note first.
class NoteProvider extends ChangeNotifier {
  NoteProvider({DatabaseService? database})
    : _database = database ?? DatabaseService.instance;

  final DatabaseService _database;
  static const _uuid = Uuid();

  List<Note> _notes = const [];
  bool _isLoading = true;

  List<Note> get notes => _notes;
  bool get isLoading => _isLoading;
  int get count => _notes.length;

  Future<void> load() async {
    _notes = await _database.getNotes();
    _isLoading = false;
    notifyListeners();
  }

  Future<Note> addNote({
    required String title,
    required String content,
    DateTime? date,
  }) async {
    final note = Note(
      id: _uuid.v4(),
      title: title,
      content: content,
      date: date ?? DateTime.now(),
    );
    await _database.addNote(note);
    _notes = [note, ..._notes];
    notifyListeners();
    return note;
  }

  Future<void> deleteNote(String id) async {
    await _database.deleteNote(id);
    _notes = _notes.where((note) => note.id != id).toList();
    notifyListeners();
  }

  Future<int> import(List<Object?> entries) async {
    final count = await _database.importNotes(entries);
    await load();
    return count;
  }

  List<Map<String, Object?>> toExportJson() =>
      _notes.map((note) => note.toJson()).toList();
}
