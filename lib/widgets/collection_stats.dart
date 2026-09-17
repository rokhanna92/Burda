import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/magazine_provider.dart';

/// The stats card: totals on the left, a lipstick on the right.
class CollectionStats extends StatelessWidget {
  const CollectionStats({super.key, required this.daysVisited});

  final int daysVisited;

  static final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');

  @override
  Widget build(BuildContext context) {
    final magazines = context.watch<MagazineProvider>();
    final latest = magazines.latestAddition;
    final oldest = magazines.oldestIssueYear;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatRow(
                    icon: 'assets/icon/magazine.png',
                    label: 'Total Magazines: ',
                    value: '${magazines.totalCount}',
                  ),
                  _StatRow(
                    icon: 'assets/icon/after.png',
                    label: 'Latest Addition: ',
                    value: latest == null ? 'N/A' : _dateFormat.format(latest),
                  ),
                  _StatRow(
                    icon: 'assets/icon/yes.png',
                    label: 'Oldest Issue: ',
                    value: oldest == null ? 'N/A' : '$oldest',
                  ),
                  _StatRow(
                    icon: 'assets/icon/fire.png',
                    label: 'Days Visited: ',
                    value: '$daysVisited',
                  ),
                ],
              ),
            ),
            Image.asset(
              'assets/icon/lipstick.png',
              width: 104,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Image.asset(icon, width: 27, height: 27),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$label$value',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
