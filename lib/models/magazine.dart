import 'dart:convert';

import 'date_label.dart';
import 'series.dart';

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
    this.isFavourite = false,
    this.contentScore,
    this.lentTo,
    this.lentOn,
    this.series = Series.style,
    int? issue,
    // A named parameter cannot be private, so this cannot be an initialising
    // formal however much the lint would like it to be.
    // ignore: prefer_initializing_formals
  }) : _issue = issue;

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

  /// Her mark on an issue worth going back to.
  ///
  /// Survives giving the copy up, unlike [conditionScore]: what is printed
  /// inside does not change because the paper left the house.
  final bool isFavourite;

  /// What is printed inside, on the same 1 to 10 scale as [conditionScore].
  /// Null means not judged.
  ///
  /// Two scores, two subjects: [conditionScore] rates the paper, this rates the
  /// patterns on it. A mint copy of an issue with nothing in it is a real thing
  /// and the shelf should be able to say so.
  final int? contentScore;

  /// How many marks the instrument prints.
  static const int contentMarks = 5;

  /// The score a tap on the nth mark writes.
  ///
  /// Even numbers on a scale of ten, so the column keeps the meaning
  /// [conditionScore] has and an average of either still reads out of ten.
  static int contentScoreFor(int marks) => marks * 2;

  /// [contentScore] as marks out of five, or null while it is not judged.
  ///
  /// Rounds up, so a 7 from a hand edited file draws four marks rather than
  /// refusing to draw. Re-tapping writes an even number back.
  int? get contentMarksFilled => contentScore == null
      ? null
      : ((contentScore! + 1) ~/ 2).clamp(1, contentMarks);

  /// What a score of [marks] is called.
  ///
  /// Five names for five marks, which is the argument for five: ten steps would
  /// need ten names and nobody can tell the seventh from the eighth.
  static String contentLabelFor(int marks) => switch (marks) {
    <= 1 => 'not for me',
    2 => 'one or two things',
    3 => 'a good issue',
    4 => 'a lot to sew',
    _ => 'one of the best',
  };

  String? get contentLabel => switch (contentMarksFilled) {
    null => null,
    final marks => contentLabelFor(marks),
  };

  /// True once she has said anything at all about what is inside.
  bool get isJudged => isFavourite || contentScore != null;

  /// Who has it, while it is out of the house. Null when it is on the shelf.
  final String? lentTo;

  /// The day it went out. Written and cleared with [lentTo], never on its own:
  /// half a loan is a row nothing can read.
  final DateTime? lentOn;

  /// True while the issue is out of the house.
  ///
  /// Lending says nothing about owning. A lent issue is still hers, still
  /// counted, still filled in on its volume. This is only about where it is.
  bool get isLent => lentTo != null;

  /// Whole days since it went out, or null while it is on the shelf.
  int? daysLent(DateTime now) =>
      lentOn == null ? null : wholeDays(lentOn!, now);

  /// True once a loan has run long enough to be printed in the accent.
  bool lentLong(DateTime now) => (daysLent(now) ?? 0) >= kLongLoan;

  /// Which shelf it stands on.
  final Series series;

  /// Set from the column once shelves exist. Null on anything written before
  /// that, and on every literal in the app that never had to say it.
  final int? _issue;

  /// Issue number within the year: the month on the main line, the running
  /// number on a shelf off it.
  int get issue => _issue ?? issueFromId(id);

  /// How this issue is named: "No. 4", or "Special No. 3".
  String get mark => series.markOf(issue);

  /// `"1-2010"` gives 1, `"special-3-2019"` gives 3.
  ///
  /// The fallback for a row written before the column existed, and the same
  /// rule the rung 8 backfill applies in SQL.
  static int issueFromId(String id) {
    final parts = id.split('-');
    return int.tryParse(parts.first) ??
        (parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0);
  }

  /// The id a new issue is filed under.
  ///
  /// The main line keeps the bare `"<issue>-<year>"` it has always used, and a
  /// shelf off it is prefixed. The asymmetry is deliberate and lives only here:
  /// those 201 ids name photo folders on disk and appear in every collection
  /// file she has ever exported, including the one from the original app, so
  /// rewriting them would buy tidiness and cost a migration.
  static String idFor({
    required Series series,
    required int issue,
    required int year,
  }) => series == Series.style ? '$issue-$year' : '${series.id}-$issue-$year';

  /// True when there is artwork to draw at all.
  bool get hasCover => image.isNotEmpty;

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
    image: _parseImage(json['image']),
    isOwned: _parseBool(json['isOwned']),
    dateAdded: _parseDate(json['dateAdded']),
    conditionScore: (json['conditionScore'] as num?)?.toInt(),
    uploadedImages: _parseImages(json['uploadedImages']),
    isFavourite: _parseBool(json['isFavourite']),
    contentScore: (json['contentScore'] as num?)?.toInt(),
    lentTo: json['lentTo'] as String?,
    lentOn: _parseDate(json['lentOn']),
    series: Series.byId(json['series'] as String?),
    issue: (json['issue'] as num?)?.toInt(),
  );

  /// Reads a row of the `magazines` table.
  factory Magazine.fromMap(Map<String, Object?> map) => Magazine(
    id: map['id'] as String,
    title: map['title'] as String,
    year: (map['year'] as num).toInt(),
    image: _parseImage(map['image']),
    isOwned: _parseBool(map['isOwned']),
    dateAdded: _parseDate(map['dateAdded']),
    conditionScore: (map['conditionScore'] as num?)?.toInt(),
    uploadedImages: _parseImages(map['uploadedImages']),
    isFavourite: _parseBool(map['isFavourite']),
    contentScore: (map['contentScore'] as num?)?.toInt(),
    lentTo: map['lentTo'] as String?,
    lentOn: _parseDate(map['lentOn']),
    series: Series.byId(map['series'] as String?),
    issue: (map['issue'] as num?)?.toInt(),
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
    'isFavourite': isFavourite ? 1 : 0,
    'contentScore': contentScore,
    'lentTo': lentTo,
    'lentOn': lentOn?.toIso8601String(),
    'series': series.id,
    'issue': issue,
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
    'isFavourite': isFavourite,
    'contentScore': contentScore,
    'lentTo': lentTo,
    'lentOn': lentOn?.toIso8601String(),
    'series': series.id,
    'issue': issue,
  };

  Magazine copyWith({
    String? image,
    bool? isOwned,
    DateTime? dateAdded,
    bool clearDateAdded = false,
    int? conditionScore,
    bool clearConditionScore = false,
    List<String>? uploadedImages,
    bool? isFavourite,
    int? contentScore,
    bool clearContentScore = false,
    String? lentTo,
    DateTime? lentOn,
    bool clearLoan = false,
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
    isFavourite: isFavourite ?? this.isFavourite,
    contentScore: clearContentScore
        ? null
        : (contentScore ?? this.contentScore),
    // One flag clears both, because they are one fact.
    lentTo: clearLoan ? null : (lentTo ?? this.lentTo),
    lentOn: clearLoan ? null : (lentOn ?? this.lentOn),
    // Neither is in the parameter list: both are fixed by the row's identity.
    series: series,
    issue: _issue,
  );

  /// Reads a cover path, whichever app wrote it.
  ///
  /// The original app stored its bundled covers as `assets/covers/1-2011.jpg`.
  /// This one stores the path relative to the asset bundle and adds the
  /// `assets/` itself, so a file exported from the original would otherwise be
  /// looked up as `assets/assets/covers/1-2011.jpg` and every one of those
  /// issues would show a bare number instead of its cover.
  ///
  /// An absolute path, which is a cover she picked herself, is left alone for
  /// [PhotoRelinkService] to deal with.
  static String _parseImage(Object? value) {
    final image = (value as String?) ?? '';
    return image.startsWith('assets/')
        ? image.substring('assets/'.length)
        : image;
  }

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
