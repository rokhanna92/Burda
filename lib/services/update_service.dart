import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../app_version.dart';

/// A release published on GitHub.
class Release {
  const Release({
    required this.version,
    required this.tag,
    required this.apkUrl,
    required this.notes,
    required this.bytes,
  });

  /// `"1.0.1"`, the tag with any leading `v` taken off.
  final String version;

  /// The tag as GitHub has it, e.g. `"v1.0.1"`.
  final String tag;

  final String apkUrl;

  /// Whatever was written in the release body.
  final String notes;

  /// Size of the apk, or 0 if GitHub did not say.
  final int bytes;

  String get size =>
      bytes == 0 ? '' : '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

/// Checks GitHub for a newer build, fetches it and hands it to Android.
///
/// Deliberately has no package behind it: a plain [HttpClient] does both calls,
/// and the install is a method channel into [MainActivity], so updating the app
/// does not drag a dependency along with it.
abstract final class UpdateService {
  /// The repository releases are published to.
  static const String repository = 'rokhanna92/Burda';

  /// Named so the install intent is obviously ours in the file provider.
  static const String downloadFolder = 'updates';

  static const MethodChannel _channel = MethodChannel('burda/update');

  /// Where the latest release is asked for.
  static Uri get endpoint =>
      Uri.parse('https://api.github.com/repos/$repository/releases/latest');

  /// The newest release, or null when there is none newer than this build.
  ///
  /// Throws when the network is unreachable, so the caller can say so; a
  /// repository with no releases at all is not an error, it is just no update.
  ///
  /// [from] and [client] exist so a test can answer for GitHub.
  static Future<Release?> check({HttpClient? client, Uri? from}) async {
    final http = client ?? HttpClient();
    try {
      final request = await http.getUrl(from ?? endpoint);
      // GitHub turns away callers that do not name themselves.
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'BurdaStyle/$kAppVersion',
      );
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github+json',
      );

      final response = await request.close();
      if (response.statusCode == HttpStatus.notFound) {
        // Nothing published yet.
        await response.drain<void>();
        return null;
      }
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw HttpException('GitHub answered ${response.statusCode}');
      }

      final body = jsonDecode(
        await response.transform(utf8.decoder).join(),
      ) as Map<String, dynamic>;
      final release = _read(body);
      if (release == null) return null;
      return isNewer(release.version, kAppVersion) ? release : null;
    } finally {
      if (client == null) http.close();
    }
  }

  /// Pulls the release apart, or null when it carries no apk.
  static Release? _read(Map<String, dynamic> body) {
    final tag = body['tag_name'] as String?;
    if (tag == null) return null;

    final assets = (body['assets'] as List?) ?? const [];
    final apk = assets.cast<Map<String, dynamic>>().where((asset) {
      final name = (asset['name'] as String?) ?? '';
      return name.toLowerCase().endsWith('.apk');
    }).firstOrNull;
    if (apk == null) return null;

    return Release(
      version: tag.startsWith('v') ? tag.substring(1) : tag,
      tag: tag,
      apkUrl: apk['browser_download_url'] as String,
      notes: ((body['body'] as String?) ?? '').trim(),
      bytes: (apk['size'] as num?)?.toInt() ?? 0,
    );
  }

  /// True when [candidate] is a later version than [current].
  ///
  /// Compares the numbers part by part, so 1.0.10 beats 1.0.9 rather than
  /// losing to it the way a string comparison would.
  static bool isNewer(String candidate, String current) {
    final left = _parts(candidate);
    final right = _parts(current);

    for (var i = 0; i < 3; i++) {
      final a = i < left.length ? left[i] : 0;
      final b = i < right.length ? right[i] : 0;
      if (a != b) return a > b;
    }
    return false;
  }

  static List<int> _parts(String version) => version
      .split('+')
      .first
      .split('.')
      .map((part) => int.tryParse(part.trim()) ?? 0)
      .toList();

  /// Fetches the apk, reporting progress between 0 and 1.
  ///
  /// Downloads beside the target and renames on success, so a download cut off
  /// half way can never be handed to the installer.
  static Future<File> download(
    Release release, {
    void Function(double progress)? onProgress,
    HttpClient? client,
  }) async {
    final directory = Directory(
      p.join((await getTemporaryDirectory()).path, downloadFolder),
    );
    if (!directory.existsSync()) await directory.create(recursive: true);

    final target = File(p.join(directory.path, 'burda-${release.tag}.apk'));
    final partial = File('${target.path}.part');

    final http = client ?? HttpClient();
    try {
      final request = await http.getUrl(Uri.parse(release.apkUrl));
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'BurdaStyle/$kAppVersion',
      );
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw HttpException('Download answered ${response.statusCode}');
      }

      final total = response.contentLength > 0
          ? response.contentLength
          : release.bytes;
      var received = 0;

      final sink = partial.openWrite();
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) onProgress?.call((received / total).clamp(0.0, 1.0));
        }
      } finally {
        await sink.close();
      }

      if (target.existsSync()) await target.delete();
      await partial.rename(target.path);
      onProgress?.call(1);
      return target;
    } catch (_) {
      if (partial.existsSync()) await partial.delete();
      rethrow;
    } finally {
      if (client == null) http.close();
    }
  }

  /// Hands the apk to Android's installer.
  ///
  /// Android asks the user to allow installs from this app the first time, and
  /// then shows its own confirmation, so nothing is installed behind their
  /// back.
  static Future<void> install(File apk) =>
      _channel.invokeMethod<void>('install', {'path': apk.path});

  /// Clears any apk left behind by an earlier update.
  static Future<void> tidy() async {
    final directory = Directory(
      p.join((await getTemporaryDirectory()).path, downloadFolder),
    );
    if (directory.existsSync()) await directory.delete(recursive: true);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
