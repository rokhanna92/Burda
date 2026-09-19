import 'dart:convert';

import 'garment_tag.dart';

/// One photographed page of an issue, and what is printed on it.
///
/// A row is a photograph, not a pattern. A contents spread carries about
/// fifteen garments, and a row for each of them is three thousand rows of
/// typing nobody will ever do. Tagging the page instead narrows "which issue
/// had that wrap dress" to a handful of issues with their contents pages on
/// screen, which was the question.
///
/// Named entry rather than page or sheet because the shell already owns both of
/// those words.
class ContentsEntry {
  const ContentsEntry({
    required this.id,
    required this.magazineId,
    required this.path,
    required this.addedOn,
    this.caption = '',
    this.tags = const {},
  });

  final String id;

  /// The issue this page came out of, held by id rather than by a foreign key:
  /// the re-seed is meant to resurrect an issue deleted by hand, and a cascade
  /// would take its pages with it on the way past.
  final String magazineId;

  /// Absolute path under `documents/contents_pages/<magazineId>/`.
  final String path;

  /// Free text. Nothing writes it yet: the first pass is zero typing, and the
  /// column is here so that the day something does, no migration is needed.
  final String caption;

  /// What is printed on this page.
  final Set<GarmentTag> tags;

  final DateTime addedOn;

  bool get isTagged => tags.isNotEmpty;

  /// The tags in the enum's own order, so the stored string is the same
  /// whichever order she tapped them in.
  List<String> get tagNames => [
    for (final tag in GarmentTag.values)
      if (tags.contains(tag)) tag.name,
  ];

  /// Reads a row of the `contents` table, or an entry of an export.
  ///
  /// One factory rather than two, unlike [Magazine]: nothing here is written
  /// differently by SQLite and by JSON except the tag list, and [parseTags]
  /// already takes both shapes.
  factory ContentsEntry.fromMap(Map<String, Object?> map) => ContentsEntry(
    id: map['id'] as String,
    magazineId: map['magazineId'] as String,
    path: map['path'] as String,
    caption: (map['caption'] as String?) ?? '',
    tags: parseTags(map['tags']),
    // A page with an unreadable date sorts to the front rather than throwing
    // the whole import away.
    addedOn:
        DateTime.tryParse(map['addedOn'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'magazineId': magazineId,
    'path': path,
    'caption': caption,
    'tags': jsonEncode(tagNames),
    'addedOn': addedOn.toIso8601String(),
  };

  /// Export shape: the tag list inline rather than encoded twice.
  Map<String, Object?> toJson() => {...toMap(), 'tags': tagNames};

  ContentsEntry copyWith({
    String? path,
    String? caption,
    Set<GarmentTag>? tags,
  }) => ContentsEntry(
    id: id,
    magazineId: magazineId,
    path: path ?? this.path,
    caption: caption ?? this.caption,
    tags: tags ?? this.tags,
    addedOn: addedOn,
  );

  /// Accepts the stored JSON string and an already decoded list, and drops a
  /// word it does not know: a file written by a later build that has one more
  /// garment in it still opens here.
  static Set<GarmentTag> parseTags(Object? value) {
    final raw = switch (value) {
      List value => value,
      String value when value.isNotEmpty => jsonDecode(value),
      _ => null,
    };
    if (raw is! List) return const {};
    return {for (final name in raw) ?GarmentTag.parse(name)};
  }
}
