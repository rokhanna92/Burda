import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/magazine.dart';
import '../providers/magazine_provider.dart';
import '../shell/burda_nav.dart';
import '../shell/collection_actions.dart';
import '../theme/edition.dart';
import '../theme/typography.dart';
import '../widgets/cover_tile.dart';
import '../widgets/page_furniture.dart';

/// One volume: every issue of a year, with a heart on each to claim it.
class YearScreen extends StatefulWidget {
  const YearScreen({super.key, required this.edition, required this.year});

  final Edition edition;
  final int year;

  /// The last year the magazine ran to twelve issues.
  static const int lastFullYear = 2025;

  @override
  State<YearScreen> createState() => _YearScreenState();
}

class _YearScreenState extends State<YearScreen> {
  /// The issue whose heart is mid-beat.
  String? _beating;
  Timer? _beat;

  @override
  void dispose() {
    _beat?.cancel();
    super.dispose();
  }

  Future<void> _toggle(Magazine magazine) async {
    setState(() => _beating = magazine.id);
    // The beat runs on its own clock. Clearing it when the database write
    // returned, which is almost at once, cut it off a frame after it started
    // and it never played.
    _beat?.cancel();
    _beat = Timer(_Heart.beat, () {
      if (mounted) setState(() => _beating = null);
    });

    await toggleIssueOwned(context, magazine);
  }

  Future<void> _fillYear(List<Magazine> present) async {
    final nav = BurdaNav.of(context);
    final magazines = context.read<MagazineProvider>();
    final have = present.map((m) => m.issue).toSet();

    var added = 0;
    for (var issue = 1; issue <= 12; issue++) {
      if (have.contains(issue)) continue;
      await magazines.addMagazine(
        Magazine(
          id: '$issue-${widget.year}',
          title: '$issue/${widget.year}',
          year: widget.year,
          image: 'covers/$issue-${widget.year}.jpg',
        ),
      );
      added++;
    }
    nav.showToast('$added issues filed under ${widget.year}');
  }

  @override
  Widget build(BuildContext context) {
    final edition = widget.edition;
    final nav = BurdaNav.of(context);
    final magazines = context.watch<MagazineProvider>();
    final issues = magazines.magazinesForYear(widget.year)
      ..sort((a, b) => a.issue.compareTo(b.issue));
    final owned = issues.where((m) => m.isOwned).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: BackLink(edition: edition, onTap: nav.back),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${widget.year}',
                style: AppType.serif(
                  size: 84,
                  weight: 300,
                  trackingEm: -0.03,
                  height: 0.85,
                  tabular: true,
                  color: edition.ink,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '$owned of ${issues.length}\nin the collection',
                    textAlign: TextAlign.end,
                    style: AppType.serif(
                      size: 17,
                      italic: true,
                      height: 1.25,
                      color: edition.inkAt(70),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ProgressRule(
            edition: edition,
            fraction: issues.isEmpty ? 0 : owned / issues.length,
            duration: const Duration(milliseconds: 700),
          ),
          const SizedBox(height: 26),
          GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 14,
            childAspectRatio: 0.58,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final (index, magazine) in issues.indexed)
                CoverIn(
                  key: ValueKey(magazine.id),
                  order: index,
                  child: _YearCover(
                    edition: edition,
                    magazine: magazine,
                    beating: _beating == magazine.id,
                    onOpen: () => nav.push(IssuePage(magazine.id)),
                    onToggle: () => _toggle(magazine),
                  ),
                ),
            ],
          ),
          if (issues.length < 12 && widget.year <= YearScreen.lastFullYear) ...[
            const SizedBox(height: 28),
            BurdaButton(
              edition: edition,
              label: 'Add the remaining issues of ${widget.year}',
              size: 17,
              padding: const EdgeInsets.all(14),
              onTap: () => _fillYear(issues),
            ),
          ],
        ],
      ),
    );
  }
}

class _YearCover extends StatelessWidget {
  const _YearCover({
    required this.edition,
    required this.magazine,
    required this.beating,
    required this.onOpen,
    required this.onToggle,
  });

  final Edition edition;
  final Magazine magazine;
  final bool beating;
  final VoidCallback onOpen;
  final VoidCallback onToggle;

  String get _condition {
    final score = magazine.conditionScore;
    if (score != null) return '${conditionWord(score)} $score';
    return magazine.isOwned ? 'unrated' : 'missing';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: PressScale(
            scale: 0.96,
            onTap: onOpen,
            child: Opacity(
              opacity: magazine.isOwned ? 1 : 0.55,
              child: CoverTile(
                magazine: magazine,
                edition: edition,
                numeralSize: 36,
                depth: CoverDepth.year,
                desaturate: !magazine.isOwned,
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: _Heart(
                      edition: edition,
                      owned: magazine.isOwned,
                      beating: beating,
                      onTap: onToggle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'No. ${magazine.issue}',
                overflow: TextOverflow.ellipsis,
                style: AppType.smallCaps(
                  size: 15,
                  trackingEm: 0.08,
                  color: edition.ink,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                _condition,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: AppType.serif(
                  size: 13,
                  italic: true,
                  color: edition.inkAt(60),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The little heart in the corner of a cover, which beats once as it is
/// claimed.
class _Heart extends StatelessWidget {
  /// How long the heart takes to swell and settle.
  static const Duration beat = Duration(milliseconds: 450);

  const _Heart({
    required this.edition,
    required this.owned,
    required this.beating,
    required this.onTap,
  });

  final Edition edition;
  final bool owned;
  final bool beating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        // Restarts whenever the beat flips on.
        key: ValueKey(beating),
        tween: Tween(begin: beating ? 0 : 1, end: 1),
        duration: beat,
        curve: Curves.ease,
        builder: (context, t, child) {
          // 1 up to 1.35 and back, the design's `pop`.
          final scale = t < 0.4
              ? 1 + 0.35 * (t / 0.4)
              : 1.35 - 0.35 * ((t - 0.4) / 0.6);
          return Transform.scale(scale: beating ? scale : 1, child: child);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: owned ? edition.accent : edition.paper,
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            owned ? '♥' : '♡',
            style: TextStyle(
              fontSize: 19,
              height: 1,
              color: owned ? edition.onAccent : edition.ink,
            ),
          ),
        ),
      ),
    );
  }
}
