/// The collector rank ladder shown on the home screen and in the rank modal.
///
/// Band thresholds are recovered from the original app; the names are the five
/// it shipped.
class CollectorRank {
  const CollectorRank(this.name, this.band, this.minimum);

  final String name;

  /// Label as the rank modal lists it, e.g. `"10-24 magazines"`.
  final String band;

  /// Lowest owned count that earns this rank.
  final int minimum;

  static const List<CollectorRank> ladder = [
    CollectorRank('Threadling', '0-9 magazines', 0),
    CollectorRank('Stitch Starter', '10-24 magazines', 10),
    CollectorRank('Fabric Fanatic', '25-49 magazines', 25),
    CollectorRank('Sartorial Stylist', '50-99 magazines', 50),
    CollectorRank('Design Diva', '100+ magazines', 100),
  ];

  static CollectorRank forOwnedCount(int ownedCount) =>
      ladder.lastWhere((rank) => ownedCount >= rank.minimum);
}
