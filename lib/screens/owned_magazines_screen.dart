import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/magazine_provider.dart';
import '../widgets/magazine_collection_view.dart';

/// Every issue she owns, newest year last.
class OwnedMagazinesScreen extends StatelessWidget {
  const OwnedMagazinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final magazines = context.watch<MagazineProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Owned')),
      body: Column(
        children: [
          const SizedBox(height: 14),
          Text('${magazines.ownedCount} owned', style: theme.textTheme.displayLarge),
          const SizedBox(height: 16),
          Expanded(
            child: MagazineCollectionView(
              magazines: magazines.owned,
              emptyMessage: 'No owned magazines',
            ),
          ),
        ],
      ),
    );
  }
}
