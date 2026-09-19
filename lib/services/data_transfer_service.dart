import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'database_service.dart';

/// Everything an export file can carry.
///
/// The first builds wrote a bare list of issues and nothing else. That file
/// still has to open, so a list is read as magazines and an empty everything
/// else.
typedef ExportBundle = ({
  List<Object?> magazines,
  List<Object?> contents,
  List<Object?> makes,
  List<Object?> notes,
  Map<String, Object?> settings,
});

/// Moves the collection in and out of the app as a JSON file.
///
/// The file keeps the original app's name, `magazines_export.json`, so a backup
/// lands beside the ones already on her phone.
abstract final class DataTransferService {
  static const String exportFileName = 'magazines_export.json';
  static const String mimeType = 'application/json';

  /// Nothing at all, for a file that could not be read as either shape.
  static const ExportBundle empty = (
    magazines: <Object?>[],
    contents: <Object?>[],
    makes: <Object?>[],
    notes: <Object?>[],
    settings: <String, Object?>{},
  );

  /// The shape written from this build on.
  ///
  /// An object rather than a list, because the collection is no longer only its
  /// issues: the pages she photographed are hers too, and an export that leaves
  /// them behind is a backup that loses the work. Keys are only ever added, so
  /// a file written here still opens in every later build, and every list this
  /// app has ever written still opens here.
  static Map<String, Object?> bundle({
    required List<Object?> magazines,
    List<Object?> contents = const [],
    List<Object?> makes = const [],
    List<Object?> notes = const [],
    Map<String, Object?> settings = const {},
    DateTime? now,
  }) => {
    'version': DatabaseService.schemaVersion,
    'exportedOn': (now ?? DateTime.now()).toIso8601String(),
    'magazines': magazines,
    'contents': contents,
    'makes': makes,
    'notes': notes,
    'settings': settings,
  };

  /// Reads either shape: the object this build writes, or the bare list the
  /// first builds and the original app wrote.
  static ExportBundle read(Object? decoded) => switch (decoded) {
    List decoded => (
      magazines: decoded,
      contents: const [],
      makes: const [],
      notes: const [],
      settings: const {},
    ),
    Map decoded => (
      magazines: decoded['magazines'] as List? ?? const [],
      contents: decoded['contents'] as List? ?? const [],
      makes: decoded['makes'] as List? ?? const [],
      notes: decoded['notes'] as List? ?? const [],
      settings:
          (decoded['settings'] as Map?)?.cast<String, Object?>() ?? const {},
    ),
    _ => empty,
  };

  /// Pretty printed so the file stays readable by hand.
  static Uint8List encode(Object? payload) => Uint8List.fromList(
    utf8.encode(const JsonEncoder.withIndent('  ').convert(payload)),
  );

  /// Asks where to put the file and writes it. Null means cancelled.
  static Future<Uri?> saveExport(Uint8List bytes) => FilePicker.saveFile(
    fileName: exportFileName,
    bytes: bytes,
    mimeType: mimeType,
  );

  /// Picks a JSON file and decodes it. Null means cancelled or unreadable.
  static Future<Object?> pickImport() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (picked == null) return null;
    return jsonDecode(utf8.decode(await picked.readAsBytes()));
  }
}
