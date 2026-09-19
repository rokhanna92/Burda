import 'dart:convert';

import 'package:burda/models/garment_tag.dart';
import 'package:burda/models/make.dart';
import 'package:burda/providers/make_provider.dart';
import 'package:burda/screens/issue_screen.dart';
import 'package:burda/screens/make_screen.dart';
import 'package:burda/screens/makes_screen.dart';
import 'package:burda/screens/vault_screen.dart';
import 'package:burda/services/database_service.dart';
import 'package:burda/shell/burda_nav.dart';
import 'package:burda/shell/burda_shell.dart';
import 'package:burda/theme/app_theme.dart';
import 'package:burda/theme/edition.dart';
import 'package:burda/widgets/nav_bar.dart';
import 'package:burda/widgets/photo_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app_providers.dart';

const _seed = [
  {
    'id': '4-2019',
    'title': '4/2019',
    'year': 2019,
    'image': 'covers/4-2019.jpg',
    'isOwned': true,
  },
];

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late DatabaseService service;
  late TestApp app;
  late MakeProvider makes;

  setUp(() async {
    service = DatabaseService(
      loadSeed: () async => jsonEncode(_seed),
      databaseName: inMemoryDatabasePath,
    );
    app = TestApp(service);
    await app.load();
    makes = app.makes;
  });

  tearDown(() => service.close());

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  }

  Future<void> tapAsync(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settle(tester);
  }

  /// Writes a make in the real async zone, which a widget test's fake one
  /// would otherwise freeze halfway.
  Future<Make> make(
    WidgetTester tester, {
    String? magazineId,
    String patternNo = '',
    GarmentTag? garment,
    String size = '',
    MakeStatus status = MakeStatus.queued,
    String? photo,
  }) async {
    late Make written;
    await tester.runAsync(() async {
      written = await makes.addMake(
        magazineId: magazineId,
        patternNo: patternNo,
        garment: garment,
        size: size,
      );
      if (status != MakeStatus.queued) {
        await makes.setStatus(written.id, status, now: DateTime(2026, 4, 2));
      }
      if (photo != null) await makes.addPhoto(written.id, photo);
      written = makes.byId(written.id)!;
    });
    return written;
  }

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1206, 7200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: app.providers,
        child: MaterialApp(
          theme: buildAppTheme(Edition.rose),
          home: const BurdaShell(),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> open(WidgetTester tester, BurdaPage page) async {
    await pumpApp(tester);
    BurdaNav.of(tester.element(find.byType(NavBar))).push(page);
    await settle(tester);
  }

  group('the journal', () {
    testWidgets('invites a first make', (tester) async {
      await open(tester, const MakesPage());

      expect(find.byType(MakesScreen), findsOneWidget);
      expect(
        find.text('Nothing made yet. Start one here, or from an issue.'),
        findsOneWidget,
      );
      expect(find.text('+ New make'), findsOneWidget);
    });

    testWidgets('groups what is on the go, waiting and made', (tester) async {
      await make(tester, garment: GarmentTag.dress, status: MakeStatus.sewing);
      await make(tester, garment: GarmentTag.coat);
      await make(tester, garment: GarmentTag.skirt, status: MakeStatus.done);
      await open(tester, const MakesPage());

      expect(find.text('On the go'), findsOneWidget);
      expect(find.text('1 under way'), findsOneWidget);
      expect(find.text('Queued'), findsOneWidget);
      expect(find.text('1 waiting'), findsOneWidget);
      expect(find.text('Made'), findsOneWidget);
      expect(find.text('1 finished'), findsOneWidget);
      // The one on the table says where it has got to; the queued one does not.
      expect(find.text('Sewing'), findsOneWidget);
      expect(find.text('2 April 2026'), findsOneWidget);
    });

    testWidgets('leaves out a group with nothing in it', (tester) async {
      await make(tester, garment: GarmentTag.coat);
      await open(tester, const MakesPage());

      expect(find.text('Queued'), findsOneWidget);
      expect(find.text('On the go'), findsNothing);
      expect(find.text('Made'), findsNothing);
    });

    testWidgets('a row opens the make', (tester) async {
      await make(tester, garment: GarmentTag.dress, patternNo: '118');
      await open(tester, const MakesPage());

      await tapAsync(tester, find.textContaining('Dress'));

      expect(find.byType(MakeScreen), findsOneWidget);
      expect(find.text('Pattern'), findsOneWidget);
      expect(find.text('118'), findsOneWidget);
    });

    testWidgets('the vault line counts both stores and opens it', (
      tester,
    ) async {
      await make(tester, garment: GarmentTag.dress, photo: '/tmp/a.jpg');
      await tester.runAsync(
        () => app.magazines.addUploadedImage('4-2019', '/tmp/b.jpg'),
      );
      await open(tester, const MakesPage());

      expect(find.text('2 photos in all'), findsOneWidget);

      await tapAsync(tester, find.textContaining('Every photo'));
      expect(find.byType(VaultScreen), findsOneWidget);
    });
  });

  group('a make', () {
    testWidgets('prints its stages and moves between them', (tester) async {
      final written = await make(tester, garment: GarmentTag.dress);
      await open(tester, MakePage(written.id));

      expect(find.text('Dress'), findsWidgets);
      expect(find.text('Queued'), findsOneWidget);

      await tapAsync(tester, find.text('Sewing'));

      expect(makes.byId(written.id)!.status, MakeStatus.sewing);
      expect(makes.byId(written.id)!.startedOn, isNotNull);
      expect(find.text('Under the needle'), findsOneWidget);
    });

    testWidgets('says so when nothing has been written down', (tester) async {
      final written = await make(tester);
      await open(tester, MakePage(written.id));

      expect(find.text('A make'), findsOneWidget);
      expect(find.text('Nothing written down yet.'), findsOneWidget);
      expect(find.text('edit →'), findsOneWidget);
    });

    testWidgets('finishing one rains hearts', (tester) async {
      final written = await make(tester, garment: GarmentTag.dress);
      await open(tester, MakePage(written.id));

      await tapAsync(tester, find.text('Done'));

      expect(find.text('Finished ♥'), findsOneWidget);
      expect(makes.byId(written.id)!.finishedOn, isNotNull);
    });

    testWidgets('prints what was written down', (tester) async {
      final written = await make(
        tester,
        magazineId: '4-2019',
        garment: GarmentTag.dress,
        patternNo: '118',
        size: '38',
      );
      await open(tester, MakePage(written.id));

      expect(find.text('from No. 4 / 2019 →'), findsOneWidget);
      expect(find.text('Pattern'), findsOneWidget);
      expect(find.text('118'), findsOneWidget);
      expect(find.text('Size'), findsOneWidget);
      expect(find.text('38'), findsOneWidget);
      expect(find.text('Nothing written down yet.'), findsNothing);
    });

    testWidgets('the issue line goes back to the issue', (tester) async {
      final written = await make(
        tester,
        magazineId: '4-2019',
        garment: GarmentTag.dress,
      );
      await open(tester, MakePage(written.id));

      await tapAsync(tester, find.text('from No. 4 / 2019 →'));

      expect(find.byType(IssueScreen), findsOneWidget);
    });

    testWidgets('brings a loose photo over from the issue', (tester) async {
      final written = await make(tester, magazineId: '4-2019');
      await tester.runAsync(
        () => app.magazines.addUploadedImage('4-2019', '/tmp/a.jpg'),
      );
      await open(tester, MakePage(written.id));

      await tapAsync(tester, find.text('From the issue'));
      expect(find.text('tap one to bring it over'), findsOneWidget);
      expect(find.text('Never mind'), findsOneWidget);

      await tapAsync(tester, find.byType(PhotoTile).first);

      expect(makes.byId(written.id)!.photos, ['/tmp/a.jpg']);
      expect(app.magazines.byId('4-2019')!.uploadedImages, isEmpty);
      expect(find.text('Brought over from the issue'), findsOneWidget);
    });

    testWidgets('offers nothing to bring over when the issue has none', (
      tester,
    ) async {
      final written = await make(tester, magazineId: '4-2019');
      await open(tester, MakePage(written.id));

      expect(find.text('From the issue'), findsNothing);
    });

    testWidgets('removing it takes it out of the journal', (tester) async {
      final written = await make(tester, garment: GarmentTag.dress);
      await open(tester, MakePage(written.id));

      await tapAsync(tester, find.text('Remove this make from the journal'));
      expect(find.text('Remove this make from the journal?'), findsOneWidget);
      expect(
        find.text('Dress, with its photos and its dates.'),
        findsOneWidget,
      );

      await tapAsync(tester, find.text('Remove'));

      expect(makes.count, 0);
      expect(find.text('Dress removed from the journal'), findsOneWidget);
      expect(find.byType(MakeScreen), findsNothing);
    });
  });

  group('the make sheet', () {
    testWidgets('starts a make and lands on it', (tester) async {
      await open(tester, const MakesPage());

      await tapAsync(tester, find.text('+ New make'));
      expect(find.text('Start a make'), findsOneWidget);

      await tapAsync(tester, find.text('Dresses'));
      await tester.enterText(find.byType(TextField).first, '118');
      await tapAsync(tester, find.text('Save make'));

      expect(makes.count, 1);
      expect(makes.makes.single.garment, GarmentTag.dress);
      expect(makes.makes.single.patternNo, '118');
      expect(find.byType(MakeScreen), findsOneWidget);
      expect(find.text('Dress added to the journal'), findsOneWidget);
    });

    testWidgets('refuses one with nothing to call it', (tester) async {
      await open(tester, const MakesPage());

      await tapAsync(tester, find.text('+ New make'));
      await tapAsync(tester, find.text('Save make'));

      expect(makes.count, 0);
      expect(find.text('Say what you are making first'), findsOneWidget);
    });

    testWidgets('edits one that already exists', (tester) async {
      final written = await make(tester, garment: GarmentTag.dress);
      await open(tester, MakePage(written.id));

      await tapAsync(tester, find.text('edit →'));
      expect(find.text('Edit this make'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(2), 'charcoal linen');
      await tapAsync(tester, find.text('Save make'));

      expect(makes.byId(written.id)!.fabric, 'charcoal linen');
      expect(find.text('Make saved'), findsOneWidget);
      expect(find.text('charcoal linen'), findsOneWidget);
    });

    testWidgets('a make started from an issue remembers the issue', (
      tester,
    ) async {
      await open(tester, const IssuePage('4-2019'));

      await tapAsync(tester, find.text('Start a make from this issue'));
      expect(find.text('From No. 4 / 2019'), findsOneWidget);

      await tapAsync(tester, find.text('Coats'));
      await tapAsync(tester, find.text('Save make'));

      expect(makes.makes.single.magazineId, '4-2019');
    });
  });

  group('an issue', () {
    testWidgets('lists the makes that came out of it', (tester) async {
      await make(
        tester,
        magazineId: '4-2019',
        garment: GarmentTag.dress,
        patternNo: '118',
      );
      await open(tester, const IssuePage('4-2019'));

      expect(find.text('Makes'), findsOneWidget);
      expect(find.text('1 from this issue'), findsOneWidget);
      // The row does not repeat the issue it is printed on.
      expect(find.textContaining('No. 4 / 2019'), findsNothing);
    });

    testWidgets('a make row opens the make', (tester) async {
      final written = await make(
        tester,
        magazineId: '4-2019',
        garment: GarmentTag.coat,
      );
      await open(tester, const IssuePage('4-2019'));

      await tapAsync(tester, find.textContaining('Coat'));

      expect(find.byType(MakeScreen), findsOneWidget);
      expect(makes.byId(written.id), isNotNull);
    });
  });

  group('the vault', () {
    testWidgets('names a make photo by its make and an issue photo by its '
        'issue', (tester) async {
      await make(
        tester,
        garment: GarmentTag.dress,
        status: MakeStatus.done,
        photo: '/tmp/a.jpg',
      );
      await tester.runAsync(
        () => app.magazines.addUploadedImage('4-2019', '/tmp/b.jpg'),
      );
      await open(tester, const VaultPage());

      expect(find.text('2 photos'), findsOneWidget);
      expect(find.text('Dress · 2026'), findsOneWidget);
      expect(find.text('No. 4 · 2019'), findsOneWidget);
    });

    testWidgets('a make photo taps through to its make', (tester) async {
      await make(tester, garment: GarmentTag.dress, photo: '/tmp/a.jpg');
      await open(tester, const VaultPage());

      await tapAsync(tester, find.textContaining('Dress · '));

      expect(find.byType(MakeScreen), findsOneWidget);
    });
  });
}
