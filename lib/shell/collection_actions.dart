import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../models/endgame.dart';
import '../models/magazine.dart';
import '../models/series.dart';
import '../providers/magazine_provider.dart';
import 'burda_nav.dart';

/// Marks [magazine] owned or sets it aside, and says the right thing about it.
///
/// The whole collection is checked before the year, unlike the design, where
/// the year branch always won and the "every issue" line could never be
/// reached: finishing your last issue also finishes its volume.
Future<void> toggleIssueOwned(BuildContext context, Magazine magazine) async {
  final magazines = context.read<MagazineProvider>();
  final nav = BurdaNav.of(context);
  final wasOwned = magazine.isOwned;
  final label = 'No. ${magazine.issue} / ${magazine.year}';

  await magazines.toggleOwnership(magazine.id);

  if (wasOwned) {
    nav.showToast(
      magazine.isLent
          ? '$label set aside, ${magazine.lentTo} keeps it'
          : '$label set aside',
    );
    return;
  }

  // The small pleasure of adding a magazine, whatever else it happens to
  // complete.
  nav.rain();

  // The main line finishing is the collection finishing, and the first time it
  // does is not the same sentence as every time after: markComplete returns
  // true only for the call that wrote the date.
  if (magazine.series == Series.style && magazines.endgame is Finished) {
    final first = await magazines.markComplete();
    nav.celebrate(
      first ? 'The whole collection. Every issue.' : 'Every issue again ♥',
    );
  } else if (magazine.series != Series.style &&
      magazines.shelfFor(magazine.series).completion == 1) {
    nav.celebrate('${magazine.series.title}. Every issue.');
  } else if (magazine.series.counted &&
      magazines.isYearComplete(magazine.year, series: magazine.series)) {
    nav.celebrate('Volume ${magazine.year} complete ♥');
  } else {
    nav.showToast('$label added');
  }
}

/// How the design words a condition score.
String conditionWord(int score) => switch (score) {
  >= 9 => 'Mint',
  >= 5 => 'Good',
  _ => 'Worn',
};
