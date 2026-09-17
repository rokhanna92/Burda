/// A Burda fact shown on the home screen, loaded from `assets/quotes.json`.
class Quote {
  const Quote({required this.type, required this.content});

  final String type;
  final String content;

  factory Quote.fromJson(Map<String, dynamic> json) => Quote(
    type: json['type'] as String? ?? 'fact',
    content: json['content'] as String,
  );
}
