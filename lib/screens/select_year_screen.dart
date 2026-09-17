import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/magazine_provider.dart';
import 'browse_magazines_screen.dart';

/// "Highlights": one progress bar per year, tapering towards the ends the way
/// the original's carousel renders them.
class SelectYearScreen extends StatelessWidget {
  const SelectYearScreen({super.key});

  /// Bars are widest in the middle of the list and narrow towards both ends.
  static double _widthFactorFor(int index, int count) {
    if (count < 2) return 1;
    final middle = (count - 1) / 2;
    final distance = (index - middle).abs() / middle;
    return 1 - 0.42 * pow(distance, 1.4);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final magazines = context.watch<MagazineProvider>();
    final years = magazines.years;

    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/icon/magazine.png', width: 30, height: 30),
      ),
      body: Column(
        children: [
          const SizedBox(height: 18),
          Text('Highlights', style: theme.textTheme.displayLarge),
          const SizedBox(height: 12),
          Text(
            'Tap a year\n'
            'to revisit every moment beautifully organized\n'
            'all in one place',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: years.isEmpty
                ? Center(
                    child: Text(
                      'No years available',
                      style: theme.textTheme.bodyLarge,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (final (index, year) in years.indexed)
                          FractionallySizedBox(
                            widthFactor: _widthFactorFor(index, years.length),
                            child: _YearBar(
                              year: year,
                              completion: magazines.completionForYear(year),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      BrowseMagazinesScreen(year: year),
                                ),
                              ),
                            ),
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

class _YearBar extends StatelessWidget {
  const _YearBar({
    required this.year,
    required this.completion,
    required this.onTap,
  });

  final int year;
  final double completion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filled = completion.clamp(0.0, 1.0);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: const Color(0xFFE2E2E2))),
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: filled,
                  child: ColoredBox(color: theme.colorScheme.primary),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$year',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      color: filled > 0.15
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '${(filled * 100).round()}%',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      color: filled > 0.9
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
