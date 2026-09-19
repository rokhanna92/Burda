/// A shelf the collection is kept on.
///
/// Burda Style is the main line: twelve to a year, cover art bundled with the
/// app, and the only shelf whose end the app knows, so it is the one the
/// headline percentage is about. The others are open ended. She fills them by
/// hand, one issue at a time, and nothing can say how many of them there are,
/// which is exactly why they cannot carry a percentage.
///
/// Stored by [id], never by index, so reordering this list cannot silently
/// reshelve the collection.
enum Series {
  style(
    id: 'style',
    title: 'Burda Style',
    shelf: 'Style',
    perYear: 12,
    firstYear: 1950,
    bundledCovers: true,
  ),
  special(
    id: 'special',
    title: 'Burda Style Special',
    shelf: 'Special',
    perYear: null,
    firstYear: 1950,
    bundledCovers: false,
  ),
  easy(
    id: 'easy',
    title: 'Burda Easy Fashion',
    shelf: 'Easy',
    perYear: null,
    firstYear: 1950,
    bundledCovers: false,
  ),
  plus(
    id: 'plus',
    title: 'Burda Style Plus',
    shelf: 'Plus',
    perYear: null,
    firstYear: 1950,
    bundledCovers: false,
  );

  const Series({
    required this.id,
    required this.title,
    required this.shelf,
    required this.perYear,
    required this.firstYear,
    required this.bundledCovers,
  });

  /// What goes in the column and in the export.
  final String id;

  /// The magazine's own name, for a heading or a subtitle.
  final String title;

  /// The short name, for a chip that has to fit four across a phone.
  final String shelf;

  /// How many issues a year holds, or null when nobody can say.
  final int? perYear;

  /// The earliest year that can be filed here.
  final int firstYear;

  /// True when the app ships artwork for this shelf.
  final bool bundledCovers;

  /// True when the shelf has a known size, and so can be a fraction of itself.
  bool get counted => perYear != null;

  /// How an issue of this shelf is named.
  ///
  /// The main line is "No. 4", the way it has always been printed. A shelf off
  /// it says which shelf, because a bare "No. 3" beside a Burda Style No. 3
  /// would be two different magazines wearing one name.
  String markOf(int issue) =>
      this == Series.style ? 'No. $issue' : '$shelf No. $issue';

  static Series byId(String? id) =>
      values.firstWhere((series) => series.id == id, orElse: () => style);
}
