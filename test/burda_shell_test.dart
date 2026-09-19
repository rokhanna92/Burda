import 'dart:convert';

import 'package:burda/models/note_provider.dart';
import 'package:burda/providers/magazine_provider.dart';
import 'package:burda/providers/theme_provider.dart';
import 'package:burda/screens/collection_screen.dart';
import 'package:burda/screens/index_screen.dart';
import 'package:burda/screens/profile_screen.dart';
import 'package:burda/screens/years_screen.dart';
import 'package:burda/services/database_service.dart';
import 'package:burda/shell/burda_nav.dart';
import 'package:burda/shell/burda_shell.dart';
import 'package:burda/theme/app_theme.dart';
import 'package:burda/theme/edition.dart';
import 'package:burda/widgets/hearts.dart';
import 'package:burda/widgets/nav_bar.dart';
import 'package:burda/widgets/toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _seed = [
  {
    'id': '1-2010',
    'title': '1/2010',
    'year': 2010,
    'image': 'covers/1-2010.jpg',
    'isOwned': true,
  },
  {
    'id': '2-2010',
    'title': '2/2010',
    'year': 2010,
    'image': 'covers/2-2010.jpg',
    'isOwned': false,
  },
];

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late DatabaseService service;
  late MagazineProvider magazines;
  late NoteProvider notes;

  setUp(() async {
    service = DatabaseService(
      loadSeed: () async => jsonEncode(_seed),
      databaseName: inMemoryDatabasePath,
    );
    magazines = MagazineProvider(database: service);
    notes = NoteProvider(database: service);
    await magazines.load();
    await notes.load();
  });

  tearDown(() => service.close());

  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: magazines),
          ChangeNotifierProvider.value(value: notes),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: MaterialApp(
          theme: buildAppTheme(Edition.rose),
          home: const BurdaShell(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Advances past the entrance animations.
  ///
  /// The nav bar's window drifts forever, so the tree never truly settles and
  /// pumpAndSettle would time out.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// The shell, reached the way a screen reaches it.
  BurdaNav nav(WidgetTester tester) =>
      BurdaNav.of(tester.element(find.byType(NavBar)));

  testWidgets('opens on the index', (tester) async {
    await pumpShell(tester);

    expect(find.byType(IndexScreen), findsOneWidget);
    expect(find.text("The collector's index"), findsOneWidget);
    expect(find.text('Burda Style'), findsOneWidget);
  });

  testWidgets('moves between the four tabs', (tester) async {
    await pumpShell(tester);

    await tester.tap(find.text('Issues'));
    await settle(tester);
    expect(find.byType(CollectionScreen), findsOneWidget);
    expect(find.byType(IndexScreen), findsNothing);

    await tester.tap(find.text('Years'));
    await settle(tester);
    expect(find.byType(YearsScreen), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await settle(tester);
    expect(find.byType(ProfileScreen), findsOneWidget);

    await tester.tap(find.text('Index'));
    await settle(tester);
    expect(find.byType(IndexScreen), findsOneWidget);
  });

  testWidgets('counts the complete volumes on the years screen', (
    tester,
  ) async {
    await pumpShell(tester);

    await tester.tap(find.text('Years'));
    await settle(tester);

    // 2010 has one owned issue of two, so nothing is complete.
    expect(find.text('0 complete volumes'), findsOneWidget);
  });

  testWidgets('floats a toast and takes it away again', (tester) async {
    await pumpShell(tester);

    expect(find.byType(Toast), findsNothing);

    nav(tester).showToast('No. 2 / 2010 added');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('No. 2 / 2010 added'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2200));
    expect(find.byType(Toast), findsNothing);
  });

  testWidgets('a second toast replaces the first', (tester) async {
    await pumpShell(tester);

    nav(tester).showToast('first');
    await tester.pump();
    nav(tester).showToast('second');
    await settle(tester);

    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2200));
  });

  testWidgets('celebrating rains hearts and says why', (tester) async {
    await pumpShell(tester);

    nav(tester).celebrate('Volume 2010 complete ♥');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(Hearts), findsOneWidget);
    expect(find.text('Volume 2010 complete ♥'), findsOneWidget);

    // The hearts clear themselves once they are done.
    await tester.pump(const Duration(milliseconds: 3000));
    await settle(tester);
    expect(find.byType(Hearts), findsNothing);
  });

  testWidgets('a pushed page leaves every tab unlit', (tester) async {
    await pumpShell(tester);

    NavBar bar() => tester.widget<NavBar>(find.byType(NavBar));
    expect(bar().current, NavTab.home);

    nav(tester).push(const NotesPage());
    await settle(tester);
    expect(bar().current, isNull);

    nav(tester).back();
    await settle(tester);
    expect(bar().current, NavTab.home);
    expect(find.byType(IndexScreen), findsOneWidget);
  });

  testWidgets('switching tab clears the pushed page', (tester) async {
    await pumpShell(tester);

    nav(tester).push(const VaultPage());
    await settle(tester);

    await tester.tap(find.text('Profile'));
    await settle(tester);

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(tester.widget<NavBar>(find.byType(NavBar)).current, NavTab.profile);
  });

  group('system back', () {
    testWidgets('pops a pushed page before anything else', (tester) async {
      await pumpShell(tester);
      nav(tester).push(const NotesPage());
      await settle(tester);

      await tester.binding.handlePopRoute();
      await settle(tester);

      expect(find.byType(IndexScreen), findsOneWidget);
    });

    testWidgets('returns to the index from another tab', (tester) async {
      await pumpShell(tester);
      await tester.tap(find.text('Years'));
      await settle(tester);

      await tester.binding.handlePopRoute();
      await settle(tester);

      expect(find.byType(IndexScreen), findsOneWidget);
    });

    testWidgets('closes an open sheet first', (tester) async {
      await pumpShell(tester);
      nav(tester).openSheet(BurdaSheet.add);
      await settle(tester);

      await tester.binding.handlePopRoute();
      await settle(tester);

      // Still on the index, having spent the back press on the sheet.
      expect(find.byType(IndexScreen), findsOneWidget);
    });
  });
}
