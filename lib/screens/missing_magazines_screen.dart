import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/magazine_provider.dart';
import '../widgets/magazine_collection_view.dart';

/// Every issue still to find.
class MissingMagazinesScreen extends StatelessWidget {
  const MissingMagazinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final magazines = context.watch<MagazineProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Missing')),
      body: Column(
        children: [
          const SizedBox(height: 14),
          Text(
            '${magazines.missingCount} missing',
            style: theme.textTheme.displayLarge,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: MagazineCollectionView(
              magazines: magazines.missing,
              emptyMessage: 'No missing magazines',
            ),
          ),
        ],
      ),
    );
  }
}
