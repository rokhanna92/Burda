import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../models/magazine.dart';
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
    nav.showToast('$label set aside');
    return;
  }
  if (magazines.ownedCount == magazines.totalCount) {
    nav.celebrate('The whole collection. Every issue.');
  } else if (magazines.isYearComplete(magazine.year)) {
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
