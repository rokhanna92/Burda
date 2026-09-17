import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/magazine_provider.dart';
import '../widgets/magazine_collection_view.dart';

/// Every issue still to find.
class MissingMagazinesScreen extends StatefulWidget {
  const MissingMagazinesScreen({super.key});

  @override
  State<MissingMagazinesScreen> createState() => _MissingMagazinesScreenState();
}

class _MissingMagazinesScreenState extends State<MissingMagazinesScreen> {
  bool _isGrid = true;

  @override
  Widget build(BuildContext context) {
    final magazines = context.watch<MagazineProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Icon(Icons.heart_broken, color: Colors.white),
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
          magazines: magazines.missing,
          carousel: !_isGrid,
          emptyMessage: 'No missing magazines',
        ),
      ),
    );
  }
}
