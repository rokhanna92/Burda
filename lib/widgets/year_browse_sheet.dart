import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/magazine_provider.dart';
import '../screens/browse_magazines_screen.dart';

/// The per-year sheet behind the arrows in the bottom bar: one card per year
/// with how many issues are owned and how many are still missing.
Future<void> showYearBrowseSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _YearBrowseSheet(),
  );
}

class _YearBrowseSheet extends StatelessWidget {
  const _YearBrowseSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final magazines = context.watch<MagazineProvider>();
    final years = magazines.years;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.6,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [theme.colorScheme.onSurface, theme.colorScheme.primary],
        ),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            height: 4,
            width: 60,
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: years.isEmpty
                ? const Center(
                    child: Text(
                      'No years available',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: years.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final year = years[index];
                      return _YearRow(
                        year: year,
                        owned: magazines.ownedCountForYear(year),
                        missing: magazines.missingCountForYear(year),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _YearRow extends StatelessWidget {
  const _YearRow({
    required this.year,
    required this.owned,
    required this.missing,
  });

  final int year;
  final int owned;
  final int missing;

  Future<void> _share(BuildContext context) async {
    final total = owned + missing;
    await SharePlus.instance.share(
      ShareParams(
        text: 'I have $owned out of $total in my Burda Style collection!',
        subject: 'My Burda Style Collection for $year',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.onSurface;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => BrowseMagazinesScreen(year: year),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Icon(Icons.heart_broken, color: accent, size: 34),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  '$year',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 24,
                    color: accent,
                  ),
                ),
              ),
              Icon(Icons.favorite, color: accent, size: 20),
              const SizedBox(width: 6),
              Text('$owned', style: theme.textTheme.bodyMedium),
              const SizedBox(width: 18),
              Icon(Icons.heart_broken, color: accent, size: 20),
              const SizedBox(width: 6),
              Text('$missing', style: theme.textTheme.bodyMedium),
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Share $year',
                icon: Icon(Icons.share, color: theme.colorScheme.primary),
                onPressed: () => _share(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
