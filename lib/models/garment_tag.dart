/// What a pattern makes.
///
/// Shared by the contents index and the sewing journal, so that "which issue
/// has a dress" and "everything I made that was a dress" are one vocabulary
/// rather than two. Closed on purpose: a word she invents once and misspells
/// twice is not a filter.
///
/// Stored by [name], never by index, so the order here is only the order the
/// words are printed in.
enum GarmentTag {
  dress('Dresses', 'Dress'),
  blouse('Blouses', 'Blouse'),
  skirt('Skirts', 'Skirt'),
  trousers('Trousers', 'Trousers'),
  jacket('Jackets', 'Jacket'),
  coat('Coats', 'Coat'),
  knitwear('Knitwear', 'Knitwear'),
  children('Children', 'For a child'),
  accessories('Accessories', 'Accessory'),
  plus('Plus sizes', 'Plus size');

  const GarmentTag(this.label, this.one);

  /// How the word is printed on a chip, where it names a whole shelf of them.
  final String label;

  /// The same word for one garment, which is what a make's own heading wants:
  /// a journal entry headed "Dresses" reads as a category rather than as the
  /// thing she sewed.
  final String one;

  /// The tag that goes by [name], or null for a word this build has not heard
  /// of, which is how a file written by a later build still opens.
  static GarmentTag? parse(Object? name) {
    for (final tag in values) {
      if (tag.name == name) return tag;
    }
    return null;
  }
}
