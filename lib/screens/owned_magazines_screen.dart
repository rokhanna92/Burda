import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/magazine_provider.dart';
import '../widgets/magazine_collection_view.dart';

/// Every issue she owns, oldest first.
class OwnedMagazinesScreen extends StatefulWidget {
  const OwnedMagazinesScreen({super.key});

  @override
  State<OwnedMagazinesScreen> createState() => _OwnedMagazinesScreenState();
}

class _OwnedMagazinesScreenState extends State<OwnedMagazinesScreen> {
  bool _isGrid = true;

  @override
  Widget build(BuildContext context) {
    final magazines = context.watch<MagazineProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Icon(Icons.favorite, color: Colors.white),
        actions: [
          IconButton(
            tooltip: _isGrid ? 'Show as carousel' : 'Show as grid',
            icon: Icon(_isGrid ? Icons.view_carousel : Icons.grid_view),
            onPressed: () => setState(() => _isGrid = !_isGrid),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: MagazineCollectionView(
          magazines: magazines.owned,
          carousel: !_isGrid,
          emptyMessage: 'No owned magazines',
        ),
      ),
    );
  }
}
