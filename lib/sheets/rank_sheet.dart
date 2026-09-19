import 'package:flutter/material.dart';

import '../models/collector_rank.dart';
import '../theme/edition.dart';
import '../theme/typography.dart';
import '../widgets/sheet_scaffold.dart';

/// The ladder, with the rung you are on picked out in the accent.
class RankSheet extends StatelessWidget {
  const RankSheet({super.key, required this.edition, required this.ownedCount});

  final Edition edition;
  final int ownedCount;

  @override
  Widget build(BuildContext context) {
    final current = CollectorRank.forOwnedCount(ownedCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SheetHeading(
          edition: edition,
          eyebrow: 'Collector rank',
          title: current.name,
        ),
        const SizedBox(height: 6),
        Text(
          '$ownedCount issues owned · ${CollectorRank.hintFor(ownedCount)}',
          style: AppType.serif(
            size: 17,
            italic: true,
            color: edition.inkAt(68),
          ),
        ),
        const SizedBox(height: 18),
        for (final rank in CollectorRank.ladder)
          _Rung(edition: edition, rank: rank, reached: rank == current),
      ],
    );
  }
}

class _Rung extends StatelessWidget {
  const _Rung({
    required this.edition,
    required this.rank,
    required this.reached,
  });

  final Edition edition;
  final CollectorRank rank;
  final bool reached;

  @override
  Widget build(BuildContext context) {
    final colour = reached ? edition.accent : edition.ink;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: edition.inkAt(12))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            // Only the mark's shape is used, tinted to the row's colour.
            child: Image.asset(
              rank.icon,
              width: 26,
              height: 26,
              color: colour,
              errorBuilder: (_, _, _) => const SizedBox(width: 26, height: 26),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              rank.name,
              style: AppType.serif(
                size: 22,
                weight: reached ? 600 : 400,
                color: colour,
              ),
            ),
          ),
          Text(
            rank.band,
            style: AppType.serif(size: 14, italic: true, color: colour),
          ),
        ],
      ),
    );
  }
}
