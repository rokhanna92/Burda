/// A standalone note. Notes are not attached to an issue.
class Note {
  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
  });

  final String id;
  final String title;
  final String content;
  final DateTime date;

  factory Note.fromMap(Map<String, Object?> map) => Note(
    id: map['id'] as String,
    title: map['title'] as String? ?? '',
    content: map['content'] as String? ?? '',
    date: _parseDate(map['date']),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'content': content,
    'date': date.toIso8601String(),
  };

  Map<String, Object?> toJson() => toMap();

  Note copyWith({String? title, String? content}) => Note(
    id: id,
    title: title ?? this.title,
    content: content ?? this.content,
    date: date,
  );

  /// The original app stored `date` as TEXT in one schema and INTEGER in
  /// another, so both are accepted here.
  static DateTime _parseDate(Object? value) => switch (value) {
    String value => DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0),
    int value => DateTime.fromMillisecondsSinceEpoch(value),
    _ => DateTime.fromMillisecondsSinceEpoch(0),
  };
}
