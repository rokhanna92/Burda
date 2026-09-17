import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/note_provider.dart';
import '../providers/magazine_provider.dart';

/// The six home tiles: owned, missing, notes, rank, vault, wear.
class InfoBlocks extends StatelessWidget {
  const InfoBlocks({
    super.key,
    this.onOwnedTap,
    this.onMissingTap,
    this.onNotesTap,
    this.onRankTap,
    this.onVaultTap,
  });

  final VoidCallback? onOwnedTap;
  final VoidCallback? onMissingTap;
  final VoidCallback? onNotesTap;
  final VoidCallback? onRankTap;
  final VoidCallback? onVaultTap;

  @override
  Widget build(BuildContext context) {
    final magazines = context.watch<MagazineProvider>();
    final noteCount = context.select<NoteProvider, int>(
      (provider) => provider.count,
    );
    final wear = magazines.averageCondition;

    final tiles = [
      _Tile(
        label: 'OWNED',
        value: '${magazines.ownedCount}',
        onTap: onOwnedTap,
      ),
      _Tile(
        label: 'MISSING',
        value: '${magazines.missingCount}',
        onTap: onMissingTap,
      ),
      _Tile(label: 'NOTES', value: '$noteCount', onTap: onNotesTap),
      _Tile(label: 'RANK', value: magazines.rank.name, onTap: onRankTap),
      _Tile(
        label: 'VAULT',
        value: '${magazines.vaultCount}',
        onTap: onVaultTap,
      ),
      _Tile(
        label: 'WEAR',
        value: wear == null ? 'N/A' : wear.toStringAsFixed(1),
      ),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      padding: EdgeInsets.zero,
      children: tiles,
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.secondary,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 5),
              FittedBox(
                child: Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
