import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Moves the collection in and out of the app as a JSON file.
///
/// The file keeps the original app's name, `magazines_export.json`, and the
/// same shape: a list of issue objects.
abstract final class DataTransferService {
  static const String exportFileName = 'magazines_export.json';
  static const String mimeType = 'application/json';

  /// Pretty printed so the file stays readable by hand.
  static Uint8List encode(List<Object?> magazines) => Uint8List.fromList(
    utf8.encode(const JsonEncoder.withIndent('  ').convert(magazines)),
  );

  /// Asks where to put the file and writes it. Null means cancelled.
  static Future<Uri?> saveExport(Uint8List bytes) => FilePicker.saveFile(
    fileName: exportFileName,
    bytes: bytes,
    mimeType: mimeType,
  );

  /// Picks a JSON file and decodes it. Null means cancelled or unreadable.
  static Future<List<Object?>?> pickImport() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (picked == null) return null;
    final decoded = jsonDecode(utf8.decode(await picked.readAsBytes()));
    return decoded is List ? decoded : null;
  }
}
