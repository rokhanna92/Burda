import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/collector_rank.dart';
import '../theme/app_theme.dart';

/// Icon shown beside each rank in the ladder, in ladder order.
const List<String?> _rankAssets = [
  null, // Threadling uses Icons.error
  'assets/icon/needle.png',
  'assets/icon/mirror.png',
  'assets/icon/machine.png',
  'assets/icon/dummy.png',
];

/// The rank ladder, opened from the RANK tile.
Future<void> showRankModal(BuildContext context, {required int ownedCount}) {
  final theme = Theme.of(context);
  final rank = CollectorRank.forOwnedCount(ownedCount);

  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        rank.name,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'You have $ownedCount owned magazines.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Rank Levels:',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          for (final (index, level) in CollectorRank.ladder.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: _rankAssets[index] == null
                        ? Icon(Icons.error, color: theme.colorScheme.onSurface)
                        : Image.asset(
                            _rankAssets[index]!,
                            width: 24,
                            height: 24,
                            color: theme.colorScheme.onSurface,
                            colorBlendMode: BlendMode.srcIn,
                          ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${level.name}: ${level.band}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [Center(child: _CloseButton())],
    ),
  );
}

/// The tour, opened from the floating question mark.
Future<void> showTourModal(BuildContext context) {
  final theme = Theme.of(context);

  Widget section(String title, List<String> bullets) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 6),
      for (final bullet in bullets)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text('• $bullet', style: theme.textTheme.bodyMedium),
        ),
      const SizedBox(height: 14),
    ],
  );

  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        'Burda Style Tour',
        textAlign: TextAlign.center,
        style: theme.textTheme.titleLarge,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            section('Bottom Navbar:', const [
              'Home: View your collection stats.',
              'Search: Find specific magazine issues.',
              'Dancing Dress: Adding a new issue.',
              'Calendar: Yearly Tracking Progress.',
              'Settings: Tweak your preferences.',
            ]),
            section('Floating Icons:', const [
              'Magnifying Glass: Search Issues by entering number and a year (2/2024).',
              'Coffee Cup: Buy me a digital coffee.',
              'Phone: Coming Soon.',
            ]),
          ],
        ),
      ),
      actions: [Center(child: _CloseButton())],
    ),
  );
}

/// The joke placeholder behind the floating phone.
Future<void> showComingSoonModal(BuildContext context) {
  final theme = Theme.of(context);
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(
        '\u{1F6A7} Under Construction! \u{1F6A7}\n\n'
        'This feature is currently just chilling in development limbo. '
        'Soon™ it will rise like a majestic phoenix or at least show up '
        'properly.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
      ),
      actions: [Center(child: _CloseButton())],
    ),
  );
}

/// The coffee cup easter egg. Counts taps, for no reward whatsoever.
Future<void> showCoffeeModal(BuildContext context) async {
  const key = 'coffee_click_count';
  final prefs = await SharedPreferences.getInstance();
  final count = (prefs.getInt(key) ?? 0) + 1;
  await prefs.setInt(key, count);
  if (!context.mounted) return;

  final theme = Theme.of(context);
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/icon/coffee-cup.png', width: 88),
          const SizedBox(height: 14),
          Text(
            'Buy me a digital coffee.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontFamily: AppFonts.display,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            count == 1 ? '1 coffee poured' : '$count coffees poured',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
      actions: [Center(child: _CloseButton())],
    ),
  );
}

class _CloseButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: theme.colorScheme.onSurface,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 12),
      ),
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Close'),
    );
  }
}
