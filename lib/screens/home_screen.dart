import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/magazine_provider.dart';
import '../providers/theme_provider.dart';
import '../services/visit_service.dart';
import '../widgets/collection_progress.dart';
import '../widgets/collection_stats.dart';
import '../widgets/floating_background.dart';
import '../widgets/home_modals.dart';
import '../widgets/info_blocks.dart';
import '../widgets/quote_display.dart';
import '../widgets/search_modal.dart';
import '../widgets/title_text.dart';
import 'gallery_screen.dart';
import 'missing_magazines_screen.dart';
import 'notes_screen.dart';
import 'owned_magazines_screen.dart';

/// The landing screen: logo, rotating fact, stats, progress and the six tiles.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _daysVisited = 0;

  @override
  void initState() {
    super.initState();
    _recordVisit();
  }

  Future<void> _recordVisit() async {
    final days = await VisitService.recordVisit();
    if (mounted) setState(() => _daysVisited = days);
  }

  void _open(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quotesEnabled = context.select<ThemeProvider, bool>(
      (provider) => provider.quotesEnabled,
    );

    return FloatingBackground(
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            children: [
              const TitleText(),
              const SizedBox(height: 18),
              if (quotesEnabled)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  // Fixed height so a longer fact does not shift the layout.
                  child: SizedBox(
                    height: 72,
                    child: Center(child: QuoteDisplay()),
                  ),
                ),
              const SizedBox(height: 28),
              CollectionStats(daysVisited: _daysVisited),
              const SizedBox(height: 26),
              const CollectionProgress(),
              const SizedBox(height: 18),
              InfoBlocks(
                onOwnedTap: () => _open(const OwnedMagazinesScreen()),
                onMissingTap: () => _open(const MissingMagazinesScreen()),
                onNotesTap: () => _open(const NotesScreen()),
                onVaultTap: () => _open(const GalleryScreen()),
                onRankTap: () => showRankModal(
                  context,
                  ownedCount: context.read<MagazineProvider>().ownedCount,
                ),
              ),
              DriftingIconCluster(
                onSearchTap: () => showSearchModal(context),
                onTourTap: () => showTourModal(context),
                onComingSoonTap: () => showComingSoonModal(context),
                onCoffeeTap: () => showCoffeeModal(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
