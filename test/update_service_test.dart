import 'dart:convert';
import 'dart:io';

import 'package:burda/app_version.dart';
import 'package:burda/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stand-in for GitHub, so the test never leaves the machine.
Future<HttpServer> _github(
  Object body, {
  int status = HttpStatus.ok,
  List<int>? apk,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    if (apk != null && request.uri.path.endsWith('.apk')) {
      request.response
        ..statusCode = HttpStatus.ok
        ..contentLength = apk.length
        ..add(apk);
      await request.response.close();
      return;
    }
    request.response
      ..statusCode = status
      ..write(jsonEncode(body));
    await request.response.close();
  });
  return server;
}

void main() {
  // No TestWidgetsFlutterBinding on purpose: it stubs every HttpClient to
  // answer 400, which would make the stand-in server below unreachable.

  group('isNewer', () {
    test('sees a later version', () {
      expect(UpdateService.isNewer('1.0.1', '1.0.0'), isTrue);
      expect(UpdateService.isNewer('1.1.0', '1.0.9'), isTrue);
      expect(UpdateService.isNewer('2.0.0', '1.9.9'), isTrue);
    });

    test('is not fooled by a string comparison', () {
      // The case that catches a naive compare: "10" sorts before "9".
      expect(UpdateService.isNewer('1.0.10', '1.0.9'), isTrue);
      expect(UpdateService.isNewer('1.0.9', '1.0.10'), isFalse);
    });

    test('says no to the same version or an older one', () {
      expect(UpdateService.isNewer('1.0.0', '1.0.0'), isFalse);
      expect(UpdateService.isNewer('0.9.9', '1.0.0'), isFalse);
    });

    test('treats a missing part as zero', () {
      expect(UpdateService.isNewer('1.1', '1.0.0'), isTrue);
      expect(UpdateService.isNewer('1', '1.0.0'), isFalse);
    });

    test('ignores a build number', () {
      expect(UpdateService.isNewer('1.0.0+7', '1.0.0+2'), isFalse);
      expect(UpdateService.isNewer('1.0.1+1', '1.0.0+9'), isTrue);
    });
  });

  group('check', () {
    late HttpServer server;

    tearDown(() => server.close(force: true));

    Future<UpdateCheck> ask(Object body, {int status = HttpStatus.ok}) async {
      server = await _github(body, status: status);
      return UpdateService.check(
        from: Uri.parse('http://${server.address.host}:${server.port}/latest'),
      );
    }

    test('offers a release that is newer than this build', () async {
      final found = await ask({
        'tag_name': 'v9.9.9',
        'body': 'Covers for 2026',
        'assets': [
          {
            'name': 'burda-style.apk',
            'browser_download_url': 'https://example.test/burda-style.apk',
            'size': 73846759,
          },
        ],
      });

      expect(found, isA<UpdateAvailable>());
      final release = (found as UpdateAvailable).release;
      expect(release.version, '9.9.9');
      expect(release.tag, 'v9.9.9');
      expect(release.notes, 'Covers for 2026');
      expect(release.apkUrl, 'https://example.test/burda-style.apk');
      expect(release.size, '70.4 MB');
    });

    test('offers nothing when the release is this build', () async {
      expect(
        await ask({
          'tag_name': 'v$kAppVersion',
          'assets': [
            {
              'name': 'a.apk',
              'browser_download_url': 'https://example.test/a.apk',
              'size': 1,
            },
          ],
        }),
        isA<NoUpdate>(),
      );
    });

    test('says so when a newer release carries no apk', () async {
      // The way to get a release wrong: publish it and forget the apk.
      // Answering "up to date" here would send you looking at the app.
      final found = await ask({'tag_name': 'v9.9.9', 'assets': <Object>[]});

      expect(found, isA<UpdateWithoutApk>());
      expect((found as UpdateWithoutApk).tag, 'v9.9.9');
    });

    test('ignores assets that are not an apk', () async {
      final found = await ask({
        'tag_name': 'v9.9.9',
        'assets': [
          {
            'name': 'notes.txt',
            'browser_download_url': 'https://example.test/notes.txt',
            'size': 1,
          },
        ],
      });

      expect(found, isA<UpdateWithoutApk>());
    });

    test(
      'treats a repository with no releases as no update, not an error',
      () async {
        expect(
          await ask({'message': 'Not Found'}, status: HttpStatus.notFound),
          isA<NoUpdate>(),
        );
      },
    );

    test('complains when GitHub answers with something else', () async {
      await expectLater(
        ask({'message': 'rate limited'}, status: HttpStatus.forbidden),
        throwsA(isA<HttpException>()),
      );
    });

    test('takes a tag without a leading v', () async {
      final found = await ask({
        'tag_name': '9.9.9',
        'assets': [
          {
            'name': 'a.apk',
            'browser_download_url': 'https://example.test/a.apk',
            'size': 0,
          },
        ],
      });

      final release = (found as UpdateAvailable).release;
      expect(release.version, '9.9.9');
      expect(release.tag, '9.9.9');
      expect(release.size, isEmpty);
    });
  });

  test('the version in the code matches the one in pubspec', () {
    final pubspec = File('pubspec.yaml').readAsLinesSync();
    final line = pubspec.firstWhere((l) => l.startsWith('version:'));
    final declared = line.split(':')[1].trim().split('+').first;

    expect(
      kAppVersion,
      declared,
      reason:
          'lib/app_version.dart and pubspec.yaml disagree, so the app cannot '
          'tell whether it is out of date',
    );
  });

  test('the repository is the one the app is published from', () {
    expect(UpdateService.repository, 'rokhanna92/Burda');
  });
}
