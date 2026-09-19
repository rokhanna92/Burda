/// The collector rank ladder shown on the profile screen and in the rank sheet.
///
/// Twelve rungs across the 201 issues, close together at the bottom where the
/// first evening's climbing happens and widening towards the top. Two names
/// are carried over from the app this one replaces: Threadling, which starts
/// the ladder as it always did, and Design Diva, moved from 100 up to 150 so a
/// title already held is promoted rather than demoted.
///
/// The names belong to sewing and to magazines in equal measure, because the
/// app sits on that seam: a toile is the calico test garment made before
/// anyone dares cut the good cloth, a standing order is what a newsagent calls
/// a subscription held in your name, and house style is both a fashion house
/// and a printing term.
class CollectorRank {
  const CollectorRank(this.name, this.band, this.minimum, this.icon);

  final String name;

  /// Label as the rank sheet lists it, e.g. `"12–19 issues"`.
  ///
  /// The bands run end to end with no gaps, so there is no count that belongs
  /// to no rung.
  final String band;

  /// Lowest owned count that earns this rank.
  final int minimum;

  /// Asset path of the rank's mark.
  ///
  /// Drawn as a mask: only its shape is used, tinted to whatever colour the
  /// row is set in. So no two rungs may share a silhouette, or they cannot be
  /// told apart in the list.
  final String icon;

  static const List<CollectorRank> ladder = [
    CollectorRank('Threadling', '0–4 issues', 0, 'assets/icon/thread.png'),
    CollectorRank('Tacking Along', '5–11 issues', 5, 'assets/icon/needle.png'),
    CollectorRank('Measure Twice', '12–19 issues', 12, 'assets/icon/tape.png'),
    CollectorRank(
      'Standing Order',
      '20–29 issues',
      20,
      'assets/icon/calendar.png',
    ),
    CollectorRank('Pedal Down', '30–44 issues', 30, 'assets/icon/machine.png'),
    CollectorRank('Toile & Error', '45–59 issues', 45, 'assets/icon/dummy.png'),
    CollectorRank('Tailor Made', '60–79 issues', 60, 'assets/icon/mirror.png'),
    CollectorRank('Cover Story', '80–99 issues', 80, 'assets/icon/dress.png'),
    CollectorRank(
      'House Style',
      '100–124 issues',
      100,
      'assets/icon/magazine.png',
    ),
    CollectorRank(
      "Editor's Pick",
      '125–149 issues',
      125,
      'assets/icon/star.png',
    ),
    CollectorRank('Design Diva', '150–184 issues', 150, 'assets/icon/hat.png'),
    CollectorRank('Dear Reader', '185+ issues', 185, 'assets/icon/books.png'),
  ];

  static CollectorRank forOwnedCount(int ownedCount) =>
      ladder.lastWhere((rank) => ownedCount >= rank.minimum);

  /// The rank above this one, or null at the top.
  static CollectorRank? above(CollectorRank rank) {
    final next = ladder.indexOf(rank) + 1;
    return next < ladder.length ? ladder[next] : null;
  }

  /// How far there is left to climb, e.g. `"6 more to Measure Twice"`.
  ///
  /// The top rung has nowhere left to point, and once other shelves push the
  /// count permanently past it that would be a dead line for good. So it says
  /// how much of the main line is still out there instead, which is the only
  /// thing left that can still change: [remaining] is how many of it are
  /// missing.
  static String hintFor(int ownedCount, {int? remaining}) {
    final next = above(forOwnedCount(ownedCount));
    if (next != null) {
      return '${next.minimum - ownedCount} more to ${next.name}';
    }
    return switch (remaining) {
      null => 'the top of the ladder',
      0 => 'the top of the ladder, and the whole shelf',
      1 => 'the top of the ladder, one issue to go',
      final left => 'the top of the ladder, $left issues to go',
    };
  }
}
