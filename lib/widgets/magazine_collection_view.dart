import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/magazine.dart';
import '../providers/magazine_provider.dart';
import '../screens/magazine_issue_detail_screen.dart';
import 'magazine_card.dart';
import 'magazine_dialogs.dart';

/// A set of issues as covers, either a two column grid or a swipeable
/// carousel, with the own, rate and delete actions wired up.
///
/// Shared by the year listing, the owned list and the missing list so the
/// cards behave the same everywhere.
class MagazineCollectionView extends StatelessWidget {
  const MagazineCollectionView({
    super.key,
    required this.magazines,
    this.carousel = false,
    this.emptyMessage = 'No magazines',
    this.onOwnedChanged,
  });

  final List<Magazine> magazines;
  final bool carousel;
  final String emptyMessage;

  /// Called after an issue is owned or disowned, so a screen can celebrate.
  final void Function(Magazine magazine, bool isOwned)? onOwnedChanged;

  @override
  Widget build(BuildContext context) {
    if (magazines.isEmpty) {
      return Center(
        child: Text(emptyMessage, style: Theme.of(context).textTheme.bodyLarge),
      );
    }
    return carousel ? _carousel(context) : _grid(context);
  }

  Widget _grid(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.72,
    ),
    itemCount: magazines.length,
    itemBuilder: (context, index) => _card(context, magazines[index]),
  );

  Widget _carousel(BuildContext context) => CarouselSlider.builder(
    itemCount: magazines.length,
    options: CarouselOptions(
      viewportFraction: 0.78,
      enlargeCenterPage: true,
      enlargeFactor: 0.2,
      enableInfiniteScroll: false,
      height: double.infinity,
    ),
    itemBuilder: (context, index, realIndex) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _card(context, magazines[index]),
    ),
  );

  Widget _card(BuildContext context, Magazine magazine) => MagazineCard(
    magazine: magazine,
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            MagazineIssueDetailScreen(magazineId: magazine.id),
      ),
    ),
    onToggleOwned: () => _toggleOwned(context, magazine),
    onRateCondition: () => _rateCondition(context, magazine),
    onDelete: () => _delete(context, magazine),
  );

  Future<void> _toggleOwned(BuildContext context, Magazine magazine) async {
    final isOwned = await context.read<MagazineProvider>().toggleOwnership(
      magazine.id,
    );
    onOwnedChanged?.call(magazine, isOwned);
  }

  Future<void> _rateCondition(BuildContext context, Magazine magazine) async {
    final provider = context.read<MagazineProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final score = await showConditionDialog(context, magazine: magazine);
    if (score == null) return;
    await provider.setCondition(magazine.id, score);
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text('Condition set to $score')));
  }

  Future<void> _delete(BuildContext context, Magazine magazine) async {
    final provider = context.read<MagazineProvider>();
    final messenger = ScaffoldMessenger.of(context);
    if (!await showDeleteIssueDialog(context)) return;
    await provider.deleteMagazine(magazine.id);
    messenger
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('Magazine removed!')));
  }
}
