import 'dart:convert';

import 'package:burda/models/note_provider.dart';
import 'package:burda/providers/magazine_provider.dart';
import 'package:burda/providers/theme_provider.dart';
import 'package:burda/screens/notes_screen.dart';
import 'package:burda/services/database_service.dart';
import 'package:burda/shell/burda_nav.dart';
import 'package:burda/shell/burda_shell.dart';
import 'package:burda/theme/app_theme.dart';
import 'package:burda/theme/edition.dart';
import 'package:burda/widgets/nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app_providers.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late DatabaseService service;
  late TestApp app;
  late NoteProvider notes;
  late MagazineProvider magazines;

  setUp(() async {
    service = DatabaseService(
      loadSeed: () async => jsonEncode(const []),
      databaseName: inMemoryDatabasePath,
    );
    app = TestApp(service);
    await app.load();
    notes = app.notes;
    magazines = app.magazines;
  });

  tearDown(() => service.close());

  /// Lets a real database write finish.
  ///
  /// A widget test runs in a fake async zone, so a sqflite future started by a
  /// tap never completes unless it is given a turn in the real one.
  Future<void> flushDatabase(WidgetTester tester) => tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );

  /// The seasonal window animates forever, so nothing ever fully settles.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Opens the app on the notes page, the way the index will.
  Future<void> openNotes(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: notes),
          ChangeNotifierProvider.value(value: magazines),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: MaterialApp(
          theme: buildAppTheme(Edition.rose),
          home: const BurdaShell(),
        ),
      ),
    );
    await settle(tester);
    BurdaNav.of(tester.element(find.byType(NavBar))).push(const NotesPage());
    await settle(tester);
  }

  testWidgets('an empty list invites a first note', (tester) async {
    await openNotes(tester);

    expect(find.byType(NotesScreen), findsOneWidget);
    expect(find.text('A blank page. Write the first line.'), findsOneWidget);
  });

  testWidgets('a saved note is listed with its date, title and body', (
    tester,
  ) async {
    await tester.runAsync(
      () => notes.addNote(
        title: 'Trench from 3/2024',
        content: 'Pattern 108. Went up one size at the hips.',
        date: DateTime(2026, 9, 2),
      ),
    );
    await openNotes(tester);

    expect(find.text('2 September 2026'), findsOneWidget);
    expect(find.text('Trench from 3/2024'), findsOneWidget);
    expect(
      find.text('Pattern 108. Went up one size at the hips.'),
      findsOneWidget,
    );
    expect(find.text('A blank page. Write the first line.'), findsNothing);
  });

  testWidgets('writes a note through the sheet', (tester) async {
    await openNotes(tester);

    await tester.tap(find.text('+ New note'));
    await settle(tester);

    await tester.enterText(find.byType(TextField).first, 'Lining swatch');
    await tester.enterText(find.byType(TextField).last, 'Navy, 1.4m left');
    await tester.tap(find.text('Save note'));
    await flushDatabase(tester);
    await settle(tester);

    expect(notes.count, 1);
    expect(notes.notes.single.title, 'Lining swatch');
    expect(notes.notes.single.content, 'Navy, 1.4m left');
    // The sheet closes and says so.
    expect(find.text('Save note'), findsNothing);
    expect(find.text('Note added'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2200));
  });

  testWidgets('refuses to save a note with nothing in it', (tester) async {
    await openNotes(tester);

    await tester.tap(find.text('+ New note'));
    await settle(tester);
    await tester.tap(find.text('Save note'));
    await settle(tester);

    expect(notes.count, 0);
    expect(find.text('Write something first'), findsOneWidget);
    // The sheet stays open so the note can still be written.
    expect(find.text('Save note'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2200));
  });

  testWidgets('trims what was typed', (tester) async {
    await openNotes(tester);

    await tester.tap(find.text('+ New note'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, '  Buttons  ');
    await tester.tap(find.text('Save note'));
    await flushDatabase(tester);
    await settle(tester);

    expect(notes.notes.single.title, 'Buttons');

    await tester.pump(const Duration(milliseconds: 2200));
  });

  testWidgets('deletes a note and says so', (tester) async {
    await tester.runAsync(
      () => notes.addNote(
        title: 'Scrap',
        content: '',
        date: DateTime(2026, 1, 4),
      ),
    );
    await openNotes(tester);

    await tester.tap(find.text('×'));
    await flushDatabase(tester);
    await settle(tester);

    expect(notes.count, 0);
    expect(find.text('Note deleted'), findsOneWidget);
    expect(find.text('A blank page. Write the first line.'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2200));
  });

  testWidgets('an untitled note still reads as a note', (tester) async {
    await tester.runAsync(
      () => notes.addNote(
        title: '',
        content: 'Just a thought',
        date: DateTime(2026, 3, 9),
      ),
    );
    await openNotes(tester);

    expect(find.text('Note'), findsOneWidget);
    expect(find.text('Just a thought'), findsOneWidget);
  });

  testWidgets('back returns to the index', (tester) async {
    await openNotes(tester);

    await tester.tap(find.text('Back'));
    await settle(tester);

    expect(find.byType(NotesScreen), findsNothing);
    expect(find.text("The collector's index"), findsOneWidget);
  });
}
