import 'package:flutter/material.dart';

import '../models/garment_tag.dart';
import '../theme/edition.dart';
import '../theme/typography.dart';
import 'page_furniture.dart';

/// A row of garment words, the picked ones printed in ink and the rest merely
/// outlined in it.
///
/// The same block marks what is on a page and asks what she is looking for, so
/// the vocabulary is learned in one place and used in the other.
class TagChips extends StatelessWidget {
  const TagChips({
    super.key,
    required this.edition,
    required this.tags,
    required this.picked,
    required this.onToggle,
    this.counts = const {},
  });

  final Edition edition;

  /// Which words to offer, in the order they are printed.
  final List<GarmentTag> tags;

  final Set<GarmentTag> picked;
  final ValueChanged<GarmentTag> onToggle;

  /// Printed after the word where there is one, e.g. "Dresses 12".
  final Map<GarmentTag, int> counts;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tag in tags)
          _Chip(
            edition: edition,
            label: tag.label,
            count: counts[tag],
            picked: picked.contains(tag),
            onTap: () => onToggle(tag),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.edition,
    required this.label,
    required this.count,
    required this.picked,
    required this.onTap,
  });

  final Edition edition;
  final String label;
  final int? count;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = picked ? edition.paper : edition.ink;

    return PressScale(
      scale: 0.94,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: picked ? edition.ink : Colors.transparent,
          border: Border.all(color: edition.inkAt(picked ? 100 : 35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              label,
              style: AppType.smallCaps(
                size: 14,
                trackingEm: 0.12,
                color: foreground,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 7),
              Text(
                '$count',
                style: AppType.serif(
                  size: 13,
                  tabular: true,
                  color: picked ? foreground : edition.inkAt(55),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
