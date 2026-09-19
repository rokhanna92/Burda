import 'dart:io';

import 'package:burda/models/magazine.dart';
import 'package:burda/services/image_storage_service.dart';
import 'package:burda/services/photo_relink_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// A photo path as the original app, under `com.example.burda`, would have
/// written it. Nothing on this device can read it.
String _oldPath(String issue, String name) =>
    '/data/user/0/com.example.burda/app_flutter/magazine_images/$issue/$name';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory documents;
  late Directory oldPhotos;

  setUp(() async {
    documents = await Directory.systemTemp.createTemp('burda-docs');
    oldPhotos = await Directory.systemTemp.createTemp('burda-old');

    // Stands in for the app's documents directory.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => documents.path,
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (documents.existsSync()) await documents.delete(recursive: true);
    if (oldPhotos.existsSync()) await oldPhotos.delete(recursive: true);
  });

  File write(Directory into, String name) {
    final file = File(p.join(into.path, name))
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3]);
    return file;
  }

  test('a photo that is still where it says is left alone', () async {
    final here = write(documents, 'kept.jpg');
    final magazine = Magazine(
      id: '3-2024',
      title: '3/2024',
      year: 2024,
      image: 'covers/3-2024.jpg',
      uploadedImages: [here.path],
    );

    final (changes, report) = await PhotoRelinkService.repair([magazine]);

    expect(changes, isEmpty);
    expect(report.alreadyThere, 1);
    expect(report.recovered, 0);
    expect(report.anyLost, isFalse);
  });

  test('finds a photo already sitting in this app under a new root', () async {
    // What copying the old data folder across leaves behind.
    write(
      Directory(p.join(documents.path, 'magazine_images', '3-2024')),
      '1699000000000.jpg',
    );
    final magazine = Magazine(
      id: '3-2024',
      title: '3/2024',
      year: 2024,
      image: 'covers/3-2024.jpg',
      uploadedImages: [_oldPath('3-2024', '1699000000000.jpg')],
    );

    final (changes, report) = await PhotoRelinkService.repair([magazine]);

    expect(report.relinked, 1);
    expect(report.anyLost, isFalse);
    expect(changes.single.id, '3-2024');
    expect(changes.single.photos.single, contains(documents.path));
    expect(File(changes.single.photos.single).existsSync(), isTrue);
  });

  test('copies a photo in from a folder it is pointed at', () async {
    write(oldPhotos, '1699000000001.jpg');
    final magazine = Magazine(
      id: '7-2023',
      title: '7/2023',
      year: 2023,
      image: 'covers/7-2023.jpg',
      uploadedImages: [_oldPath('7-2023', '1699000000001.jpg')],
    );

    final (changes, report) = await PhotoRelinkService.repair([
      magazine,
    ], sourceFolder: oldPhotos);

    expect(report.copied, 1);
    expect(report.anyLost, isFalse);
    expect(File(changes.single.photos.single).existsSync(), isTrue);
  });

  test('searches the folder it is pointed at, however deep', () async {
    write(
      Directory(
        p.join(oldPhotos.path, 'app_flutter', 'magazine_images', '1-2020'),
      ),
      'buried.jpg',
    );
    final magazine = Magazine(
      id: '1-2020',
      title: '1/2020',
      year: 2020,
      image: 'covers/1-2020.jpg',
      uploadedImages: [_oldPath('1-2020', 'buried.jpg')],
    );

    final (_, report) = await PhotoRelinkService.repair([
      magazine,
    ], sourceFolder: oldPhotos);

    expect(report.copied, 1);
  });

  test('counts a photo it cannot find anywhere', () async {
    final magazine = Magazine(
      id: '2-2019',
      title: '2/2019',
      year: 2019,
      image: 'covers/2-2019.jpg',
      uploadedImages: [_oldPath('2-2019', 'gone.jpg')],
    );

    final (changes, report) = await PhotoRelinkService.repair([magazine]);

    expect(report.lost, 1);
    expect(report.anyLost, isTrue);
    // The issue survives; only the dead path is dropped.
    expect(changes.single.photos, isEmpty);
  });

  test('a lost cover falls back to the artwork the app ships', () async {
    final magazine = Magazine(
      id: '4-2018',
      title: '4/2018',
      year: 2018,
      image: _oldPath('4-2018', 'her-own-cover.jpg'),
    );
    expect(magazine.hasFileCover, isTrue);

    final (changes, report) = await PhotoRelinkService.repair([magazine]);

    expect(report.lost, 1);
    expect(changes.single.cover, 'covers/4-2018.jpg');
  });

  test('restores a cover from the folder it is pointed at', () async {
    write(oldPhotos, 'her-own-cover.jpg');
    final magazine = Magazine(
      id: '4-2018',
      title: '4/2018',
      year: 2018,
      image: _oldPath('4-2018', 'her-own-cover.jpg'),
    );

    final (changes, report) = await PhotoRelinkService.repair([
      magazine,
    ], sourceFolder: oldPhotos);

    expect(report.copied, 1);
    expect(changes.single.cover, contains(ImageStorageService.coverFolder));
    expect(File(changes.single.cover!).existsSync(), isTrue);
  });

  test('leaves a bundled cover alone', () async {
    const magazine = Magazine(
      id: '5-2015',
      title: '5/2015',
      year: 2015,
      image: 'covers/5-2015.jpg',
    );

    final (changes, report) = await PhotoRelinkService.repair([magazine]);

    expect(changes, isEmpty);
    expect(report.lost, 0);
  });

  test('reports across a whole collection', () async {
    final here = write(documents, 'kept.jpg');
    write(oldPhotos, 'findable.jpg');

    final magazines = [
      Magazine(
        id: '1-2024',
        title: '1/2024',
        year: 2024,
        image: 'covers/1-2024.jpg',
        uploadedImages: [here.path],
      ),
      Magazine(
        id: '2-2024',
        title: '2/2024',
        year: 2024,
        image: 'covers/2-2024.jpg',
        uploadedImages: [_oldPath('2-2024', 'findable.jpg')],
      ),
      Magazine(
        id: '3-2024',
        title: '3/2024',
        year: 2024,
        image: 'covers/3-2024.jpg',
        uploadedImages: [_oldPath('3-2024', 'gone.jpg')],
      ),
    ];

    final (_, report) = await PhotoRelinkService.repair(
      magazines,
      sourceFolder: oldPhotos,
    );

    expect(report.alreadyThere, 1);
    expect(report.copied, 1);
    expect(report.lost, 1);
    expect(report.recovered, 1);
  });
}
