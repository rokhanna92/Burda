import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/magazine.dart';
import '../providers/magazine_provider.dart';
import '../widgets/magazine_collection_view.dart';

/// Every issue of one year, as a cover carousel or a two column grid.
class BrowseMagazinesScreen extends StatefulWidget {
  const BrowseMagazinesScreen({super.key, required this.year});

  final int year;

  @override
  State<BrowseMagazinesScreen> createState() => _BrowseMagazinesScreenState();
}

class _BrowseMagazinesScreenState extends State<BrowseMagazinesScreen> {
  static const String _viewKey = 'isGridView';

  late final ConfettiController _confetti = ConfettiController(
    duration: const Duration(seconds: 2),
  );

  bool _isGrid = true;

  @override
  void initState() {
    super.initState();
    _loadViewPreference();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _loadViewPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _isGrid = prefs.getBool(_viewKey) ?? true);
  }

  Future<void> _toggleView() async {
    setState(() => _isGrid = !_isGrid);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_viewKey, _isGrid);
  }

  /// Completing a year is worth confetti.
  void _onOwnedChanged(Magazine magazine, bool isOwned) {
    if (isOwned &&
        context.read<MagazineProvider>().isYearComplete(widget.year)) {
      _confetti.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final issues = context.select<MagazineProvider, List<Magazine>>(
      (provider) => provider.magazinesForYear(widget.year),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.year}'),
        actions: [
          IconButton(
            tooltip: _isGrid ? 'Show as carousel' : 'Show as grid',
            icon: Icon(_isGrid ? Icons.view_carousel : Icons.grid_view),
            onPressed: _toggleView,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 18),
              Text('Browse Issues', style: theme.textTheme.displayLarge),
              const SizedBox(height: 10),
              Text(
                'Tap a year, meet its issues\n'
                'twelve chances to judge a cover by it',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 22),
              Expanded(
                child: MagazineCollectionView(
                  magazines: issues,
                  carousel: !_isGrid,
                  emptyMessage: 'No magazines for ${widget.year}',
                  onOwnedChanged: _onOwnedChanged,
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 18,
              shouldLoop: false,
            ),
          ),
        ],
      ),
    );
  }
}
