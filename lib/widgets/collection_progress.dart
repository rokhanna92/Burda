import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/magazine_provider.dart';

/// Full width completion bar with the percentage written across it.
class CollectionProgress extends StatelessWidget {
  const CollectionProgress({super.key, this.height = 24});

  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final completion = context.select<MagazineProvider, double>(
      (provider) => provider.completion,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: completion.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => Stack(
          alignment: Alignment.center,
          children: [
            Container(height: height, color: scheme.secondary),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: value,
                child: Container(height: height, color: scheme.primary),
              ),
            ),
            Text(
              '${(value * 100).round()}%',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
