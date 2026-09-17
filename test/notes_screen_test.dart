import 'dart:convert';

import 'package:burda/models/note_provider.dart';
import 'package:burda/providers/theme_provider.dart';
import 'package:burda/screens/notes_screen.dart';
import 'package:burda/services/database_service.dart';
import 'package:burda/theme/app_theme.dart';
import 'package:burda/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late DatabaseService service;
  late NoteProvider notes;

  setUp(() async {
    service = DatabaseService(
      loadSeed: () async => jsonEncode(const []),
      databaseName: inMemoryDatabasePath,
    );
    notes = NoteProvider(database: service);
    await notes.load();
  });

  tearDown(() => service.close());

  Future<void> pumpNotes(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: notes),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: MaterialApp(
          theme: buildAppTheme(Palette.pink),
          home: const NotesScreen(),
        ),
      ),
    );
    // Explicit pumps rather than pumpAndSettle: the Material ink and the
    // dialog transition keep scheduling frames, so settling never finishes.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('an empty list invites a first note', (tester) async {
    await pumpNotes(tester);

    expect(find.text('Add a new note!'), findsOneWidget);
    expect(find.text('Add Note'), findsOneWidget);
  });

  testWidgets('a saved note is listed with room to be seen', (tester) async {
    // Database work has to escape the fake async zone a widget test runs in,
    // otherwise the real sqflite future never completes and the test hangs.
    await tester.runAsync(
      () => notes.addNote(title: 'Fabric shop', content: 'Check Burda 3/2019'),
    );

    await pumpNotes(tester);

    expect(find.text('Fabric shop'), findsOneWidget);
    expect(find.text('Check Burda 3/2019'), findsOneWidget);
    // The bottom button must not swallow the body: a bottom bar child gets
    // loose height constraints, so an Align there takes the whole screen.
    expect(tester.getSize(find.byType(ListView)).height, greaterThan(100));
  });

  testWidgets('the add dialog opens with both fields', (tester) async {
    await pumpNotes(tester);

    await tester.tap(find.text('Add Note'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Content'), findsOneWidget);
    expect(find.text('SAVE'), findsOneWidget);
  });
}
