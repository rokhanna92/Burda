/// The collector rank ladder shown on the profile screen and in the rank sheet.
///
/// Band thresholds are recovered from the original app; the names are the five
/// it shipped. The redesign counts "issues" rather than "magazines" and prints
/// the range with an en dash.
class CollectorRank {
  const CollectorRank(this.name, this.band, this.minimum, this.icon);

  final String name;

  /// Label as the rank sheet lists it, e.g. `"10–24 issues"`.
  final String band;

  /// Lowest owned count that earns this rank.
  final int minimum;

  /// Asset path of the rank's mark.
  ///
  /// Drawn as a mask: only its shape is used, tinted to whatever colour the
  /// row is set in.
  final String icon;

  static const List<CollectorRank> ladder = [
    CollectorRank('Threadling', '0–9 issues', 0, 'assets/icon/thread.png'),
    CollectorRank(
      'Stitch Starter',
      '10–24 issues',
      10,
      'assets/icon/needle.png',
    ),
    CollectorRank(
      'Fabric Fanatic',
      '25–49 issues',
      25,
      'assets/icon/mirror.png',
    ),
    CollectorRank(
      'Sartorial Stylist',
      '50–99 issues',
      50,
      'assets/icon/machine.png',
    ),
    CollectorRank('Design Diva', '100+ issues', 100, 'assets/icon/dummy.png'),
  ];

  static CollectorRank forOwnedCount(int ownedCount) =>
      ladder.lastWhere((rank) => ownedCount >= rank.minimum);

  /// The rank above this one, or null at the top.
  static CollectorRank? above(CollectorRank rank) {
    final next = ladder.indexOf(rank) + 1;
    return next < ladder.length ? ladder[next] : null;
  }

  /// How far there is left to climb, e.g. `"6 more to Fabric Fanatic"`.
  static String hintFor(int ownedCount) {
    final next = above(forOwnedCount(ownedCount));
    if (next == null) return 'the top of the ladder';
    return '${next.minimum - ownedCount} more to ${next.name}';
  }
}
