import 'dart:convert';

/// A single Burda Style issue.
///
/// Seeded from `assets/magazines.json` and stored in the `magazines` table.
class Magazine {
  const Magazine({
    required this.id,
    required this.title,
    required this.year,
    required this.image,
    this.isOwned = false,
    this.dateAdded,
    this.conditionScore,
    this.uploadedImages = const [],
  });

  /// `"<issue>-<year>"`, e.g. `"1-2010"`.
  final String id;

  /// `"<issue>/<year>"`, e.g. `"1/2010"`.
  final String title;
  final int year;

  /// Asset path relative to `assets/`, e.g. `"covers/1-2010.jpg"`.
  final String image;
  final bool isOwned;

  /// When the issue was marked owned. Null while it is missing.
  final DateTime? dateAdded;

  /// Condition on a 1 (Worn) to 10 (Mint) scale. Null means not rated yet.
  final int? conditionScore;

  /// Absolute paths of photos the user attached to this issue.
  final List<String> uploadedImages;

  /// Issue number within the year, e.g. `1` for `"1-2010"`.
  int get issue => int.parse(id.split('-').first);

  /// True when [image] points at a file the user chose, rather than one of the
  /// covers bundled with the app.
  bool get hasFileCover => image.startsWith('/');

  /// Legacy wording for [conditionScore], matching the original app's labels.
  String? get conditionLabel => switch (conditionScore) {
    null => null,
    >= 9 => 'Mint',
    >= 5 => 'Good',
    _ => 'Worn',
  };

  /// Reads a seed entry from `assets/magazines.json`.
  factory Magazine.fromJson(Map<String, dynamic> json) => Magazine(
    id: json['id'] as String,
    title: json['title'] as String,
    year: json['year'] as int,
    image: json['image'] as String,
    isOwned: _parseBool(json['isOwned']),
    dateAdded: _parseDate(json['dateAdded']),
    conditionScore: (json['conditionScore'] as num?)?.toInt(),
    uploadedImages: _parseImages(json['uploadedImages']),
  );

  /// Reads a row of the `magazines` table.
  factory Magazine.fromMap(Map<String, Object?> map) => Magazine(
    id: map['id'] as String,
    title: map['title'] as String,
    year: (map['year'] as num).toInt(),
    image: map['image'] as String,
    isOwned: _parseBool(map['isOwned']),
    dateAdded: _parseDate(map['dateAdded']),
    conditionScore: (map['conditionScore'] as num?)?.toInt(),
    uploadedImages: _parseImages(map['uploadedImages']),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'year': year,
    'image': image,
    'isOwned': isOwned ? 1 : 0,
    'dateAdded': dateAdded?.toIso8601String(),
    'conditionScore': conditionScore,
    'uploadedImages': jsonEncode(uploadedImages),
  };

  /// Export shape: a plain JSON object, with the image list inline.
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'year': year,
    'image': image,
    'isOwned': isOwned,
    'dateAdded': dateAdded?.toIso8601String(),
    'conditionScore': conditionScore,
    'uploadedImages': uploadedImages,
  };

  Magazine copyWith({
    String? image,
    bool? isOwned,
    DateTime? dateAdded,
    bool clearDateAdded = false,
    int? conditionScore,
    bool clearConditionScore = false,
    List<String>? uploadedImages,
  }) => Magazine(
    id: id,
    title: title,
    year: year,
    image: image ?? this.image,
    isOwned: isOwned ?? this.isOwned,
    dateAdded: clearDateAdded ? null : (dateAdded ?? this.dateAdded),
    conditionScore: clearConditionScore
        ? null
        : (conditionScore ?? this.conditionScore),
    uploadedImages: uploadedImages ?? this.uploadedImages,
  );

  /// SQLite stores a flag as 0 or 1, JSON writes true or false, and an export
  /// from the original app wrote the string "1". All three mean the same thing,
  /// and every flag added from here on reads through this in both factories.
  static bool _parseBool(Object? value) =>
      value == true || value == 1 || value == '1';

  static DateTime? _parseDate(Object? value) => switch (value) {
    String value => DateTime.tryParse(value),
    int value => DateTime.fromMillisecondsSinceEpoch(value),
    _ => null,
  };

  /// Accepts both the stored JSON string and an already decoded list.
  static List<String> _parseImages(Object? value) {
    switch (value) {
      case List value:
        return value.cast<String>();
      case String value when value.isNotEmpty:
        final decoded = jsonDecode(value);
        return decoded is List ? decoded.cast<String>() : const [];
      default:
        return const [];
    }
  }
}
