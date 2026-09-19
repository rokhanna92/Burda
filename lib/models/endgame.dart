import 'magazine.dart';

/// The main line's numbers, which is what the endgame is judged on.
///
/// A record rather than four getters because the four are only ever read
/// together, and walking 201 rows once for all of them is the same walk the
/// provider already does for one.
typedef MainLine = ({
  int owned,
  int total,
  List<Magazine> missing,
  List<int> years,
});

/// How close the main line is to finished, which is what the index leads with.
///
/// Three states rather than one percentage, because the last stretch and the
/// end itself are not simply smaller numbers. With a lot left, a percentage is
/// the honest summary. With a handful, the issues can be named. At the end
/// there is nothing left to be a percentage of, and a tile reading 100% for
/// ever is the app saying nothing at all. Sealed, so the index has to answer
/// for all three.
sealed class Endgame {
  const Endgame();

  /// Stored in the `settings` table, and carried in an export.
  static const String completedOnKey = 'collection.completedOn';

  /// How few are left before they are worth naming one by one.
  ///
  /// Four addresses stop being a card and start being a list, and the Missing
  /// tab is already a better list than the index will ever be.
  static const int nameable = 3;

  /// Where the collection stands, from the shelf and the day it was finished.
  factory Endgame.of({
    required int total,
    required List<Magazine> missing,
    required DateTime? completedOn,
  }) {
    // An empty shelf is not a finished one. Nothing seeded yet, or every row
    // deleted by hand, and the index must not congratulate her for it. Every
    // branch below may therefore assume the shelf has rows on it, and so at
    // least one year.
    if (total == 0) return const Climbing();
    return switch (missing.length) {
      0 => Finished(completedOn),
      <= nameable => LastFew(missing),
      _ => const Climbing(),
    };
  }
}

/// Too many left to name, so the index says how far along instead.
final class Climbing extends Endgame {
  const Climbing();
}

/// Few enough left to print by address, with somewhere to tap on each.
final class LastFew extends Endgame {
  const LastFew(this.issues);

  /// Oldest first, which is the order the provider already holds them in.
  final List<Magazine> issues;
}

/// Every issue of the main line held.
final class Finished extends Endgame {
  const Finished(this.completedOn);

  /// The day it was first finished, or null while the app has not stamped it.
  ///
  /// It survives an issue going back out of the house. The collection can fall
  /// under and come back; the day she finished it does not move.
  final DateTime? completedOn;
}
