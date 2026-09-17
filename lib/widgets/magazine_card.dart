import 'package:flutter/material.dart';

import '../models/magazine.dart';

/// A cover with the action bar across its lower third: own or disown, rate the
/// condition once owned, and delete.
class MagazineCard extends StatelessWidget {
  const MagazineCard({
    super.key,
    required this.magazine,
    this.onTap,
    required this.onToggleOwned,
    required this.onRateCondition,
    required this.onDelete,
  });

  final Magazine magazine;
  final VoidCallback? onTap;
  final VoidCallback onToggleOwned;
  final VoidCallback onRateCondition;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/${magazine.image}',
            fit: BoxFit.cover,
            // The original shipped no placeholder, so a missing cover crashed
            // the tile. This shows the issue number instead.
            errorBuilder: (context, error, stack) => ColoredBox(
              color: Theme.of(context).colorScheme.secondary,
              child: Center(
                child: Text(
                  magazine.title,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 14,
            child: Container(
              color: Colors.black.withValues(alpha: 0.32),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  _BarIcon(
                    icon: magazine.isOwned
                        ? Icons.favorite
                        : Icons.heart_broken,
                    color: magazine.isOwned ? const Color(0xFFF44336) : null,
                    tooltip: magazine.isOwned
                        ? 'Remove from collection'
                        : 'Add to collection',
                    onTap: onToggleOwned,
                  ),
                  Expanded(
                    child: Text(
                      magazine.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
                  if (magazine.isOwned)
                    _ConditionIcon(
                      rated: magazine.conditionScore != null,
                      onTap: onRateCondition,
                    ),
                  _BarIcon(
                    icon: Icons.delete,
                    tooltip: 'Delete issue',
                    onTap: onDelete,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarIcon extends StatelessWidget {
  const _BarIcon({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: Tooltip(
        message: tooltip,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 21, color: color ?? Colors.white),
        ),
      ),
    );
  }
}

/// The condition button only appears on an owned issue. It stays a white
/// silhouette until a score is saved, then shows in its own colours.
class _ConditionIcon extends StatelessWidget {
  const _ConditionIcon({required this.rated, required this.onTap});

  final bool rated;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: Tooltip(
        message: rated ? 'Change condition' : 'Rate condition',
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Image.asset(
            'assets/icon/document.png',
            width: 21,
            height: 21,
            color: rated ? null : Colors.white,
            colorBlendMode: rated ? null : BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}
