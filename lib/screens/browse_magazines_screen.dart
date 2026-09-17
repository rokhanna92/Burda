import 'package:carousel_slider/carousel_slider.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/magazine.dart';
import '../providers/magazine_provider.dart';
import '../widgets/magazine_card.dart';
import '../widgets/magazine_dialogs.dart';
import 'magazine_issue_detail_screen.dart';

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

  Future<void> _toggleOwned(Magazine magazine) async {
    final provider = context.read<MagazineProvider>();
    final wasComplete = provider.isYearComplete(widget.year);
    await provider.toggleOwnership(magazine.id);
    if (!wasComplete && provider.isYearComplete(widget.year)) {
      _confetti.play();
    }
  }

  Future<void> _rateCondition(Magazine magazine) async {
    final provider = context.read<MagazineProvider>();
    final score = await showConditionDialog(context, magazine: magazine);
    if (score == null) return;
    await provider.setCondition(magazine.id, score);
    if (mounted) _notify('Condition set to $score');
  }

  Future<void> _delete(Magazine magazine) async {
    final provider = context.read<MagazineProvider>();
    if (!await showDeleteIssueDialog(context)) return;
    await provider.deleteMagazine(magazine.id);
    if (mounted) _notify('Magazine removed!');
  }

  void _openDetail(Magazine magazine) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            MagazineIssueDetailScreen(magazineId: magazine.id),
      ),
    );
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
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
                child: issues.isEmpty
                    ? Center(
                        child: Text(
                          'No magazines for ${widget.year}',
                          style: theme.textTheme.bodyLarge,
                        ),
                      )
                    : _isGrid
                    ? _grid(issues)
                    : _carousel(issues),
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

  Widget _grid(List<Magazine> issues) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.72,
      ),
      itemCount: issues.length,
      itemBuilder: (context, index) => _card(issues[index]),
    );
  }

  Widget _carousel(List<Magazine> issues) {
    return CarouselSlider.builder(
      itemCount: issues.length,
      options: CarouselOptions(
        viewportFraction: 0.78,
        enlargeCenterPage: true,
        enlargeFactor: 0.2,
        enableInfiniteScroll: false,
        height: double.infinity,
      ),
      itemBuilder: (context, index, realIndex) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _card(issues[index]),
      ),
    );
  }

  Widget _card(Magazine magazine) => MagazineCard(
    magazine: magazine,
    onTap: () => _openDetail(magazine),
    onToggleOwned: () => _toggleOwned(magazine),
    onRateCondition: () => _rateCondition(magazine),
    onDelete: () => _delete(magazine),
  );
}
