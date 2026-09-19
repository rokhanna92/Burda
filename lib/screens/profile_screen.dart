import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/collector_rank.dart';
import '../providers/magazine_provider.dart';
import '../providers/theme_provider.dart';
import '../services/data_transfer_service.dart';
import '../shell/burda_nav.dart';
import '../theme/edition.dart';
import '../theme/motion.dart';
import '../theme/typography.dart';
import '../widgets/page_furniture.dart';

/// The colophon: your rank, the édition the app is printed in, and the
/// archive.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.edition});

  final Edition edition;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _busy = false;

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    final nav = BurdaNav.of(context);
    try {
      final bytes = DataTransferService.encode(
        context.read<MagazineProvider>().toExportJson(),
      );
      final location = await DataTransferService.saveExport(bytes);
      nav.showToast(
        location == null ? 'Export cancelled' : 'Collection exported',
      );
    } catch (error) {
      nav.showToast('Could not export');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    setState(() => _busy = true);
    final nav = BurdaNav.of(context);
    try {
      final entries = await DataTransferService.pickImport();
      if (entries == null) {
        nav.showToast('No file chosen');
        return;
      }
      if (!mounted) return;
      final magazines = context.read<MagazineProvider>();
      final count = await magazines.import(entries);
      nav.showToast('$count issues restored');
      if (magazines.completion == 1) {
        nav.celebrate('The whole collection. Every issue.');
      }
    } catch (error) {
      nav.showToast('Could not read that file');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final edition = widget.edition;
    final nav = BurdaNav.of(context);
    final owned = context.select<MagazineProvider, int>((m) => m.ownedCount);
    final rank = CollectorRank.forOwnedCount(owned);

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kGutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Eyebrow('Colophon', edition: edition),
                const SizedBox(height: 4),
                ScreenTitle('Profile', edition: edition),
                const SizedBox(height: 24),
                _RankCard(
                  edition: edition,
                  rank: rank,
                  hint: CollectorRank.hintFor(owned),
                  onTap: () => nav.openSheet(BurdaSheet.rank),
                ),
                const SizedBox(height: 34),
                SectionHeader(
                  'Édition',
                  edition: edition,
                  note: 'the season the app is printed in',
                ),
                const SizedBox(height: 14),
                _RowLabel('Day', edition: edition),
              ],
            ),
          ),
          _EditionRow(current: edition, editions: Edition.day),
          Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 10, kGutter, 0),
            child: _RowLabel('Night', edition: edition),
          ),
          _EditionRow(current: edition, editions: Edition.night),
          Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 30, kGutter, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'The archive',
                  style: AppType.smallCaps(
                    size: 13,
                    trackingEm: 0.22,
                    color: edition.ink,
                  ),
                ),
                const SizedBox(height: 4),
                _ArchiveRow(
                  edition: edition,
                  title: 'Export collection',
                  sub: 'a .json you can keep anywhere',
                  glyph: '↓',
                  onTap: _busy ? null : _export,
                ),
                _ArchiveRow(
                  edition: edition,
                  title: 'Import collection',
                  sub: 'restore from a file',
                  glyph: '↑',
                  onTap: _busy ? null : _import,
                ),
                _ArchiveRow(
                  edition: edition,
                  title: 'About Burda Style',
                  sub: 'version 2.0',
                  glyph: '→',
                  onTap: () => nav.openSheet(BurdaSheet.about),
                ),
                const SizedBox(height: 28),
                Text(
                  'Everything lives on this phone. '
                  'Nothing leaves it unless you export.',
                  textAlign: TextAlign.center,
                  style: AppType.serif(
                    size: 14,
                    italic: true,
                    color: edition.inkAt(55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RowLabel extends StatelessWidget {
  const _RowLabel(this.text, {required this.edition});

  final String text;
  final Edition edition;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppType.smallCaps(
      size: 12,
      trackingEm: 0.18,
      color: edition.inkAt(55),
    ),
  );
}

class _RankCard extends StatelessWidget {
  const _RankCard({
    required this.edition,
    required this.rank,
    required this.hint,
    required this.onTap,
  });

  final Edition edition;
  final CollectorRank rank;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(border: Border.all(color: edition.ink)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Collector rank',
                    style: AppType.smallCaps(
                      size: 13,
                      trackingEm: 0.2,
                      color: edition.accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rank.name,
                    style: AppType.serif(
                      size: 34,
                      weight: 500,
                      height: 1.05,
                      color: edition.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hint,
                    style: AppType.serif(
                      size: 15,
                      italic: true,
                      color: edition.inkAt(65),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Image.asset(
              rank.icon,
              width: 52,
              height: 52,
              color: edition.ink,
              errorBuilder: (_, _, _) => const SizedBox(width: 52, height: 52),
            ),
          ],
        ),
      ),
    );
  }
}

/// A scrolling row of édition cards, each printed in its own colours.
class _EditionRow extends StatelessWidget {
  const _EditionRow({required this.current, required this.editions});

  final Edition current;
  final List<Edition> editions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 178,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 10),
        itemCount: editions.length,
        separatorBuilder: (context, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _EditionCard(
          edition: editions[index],
          selected: editions[index].id == current.id,
          outline: current.accent,
        ),
      ),
    );
  }
}

class _EditionCard extends StatelessWidget {
  const _EditionCard({
    required this.edition,
    required this.selected,
    required this.outline,
  });

  final Edition edition;
  final bool selected;

  /// The outline is the *current* édition's accent, so the selection reads as
  /// part of the page rather than part of the card.
  final Color outline;

  @override
  Widget build(BuildContext context) {
    final theme = context.read<ThemeProvider>();
    final nav = BurdaNav.of(context);

    return PressScale(
      scale: 0.95,
      onTap: () {
        theme.setEdition(edition);
        nav.showToast('Printed in the ${edition.name} edition');
      },
      child: AnimatedSlide(
        // The chosen édition lifts a touch off the row.
        offset: selected ? const Offset(0, -0.026) : Offset.zero,
        duration: const Duration(milliseconds: 250),
        curve: AppMotion.standard,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 112,
          height: 156,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          decoration: BoxDecoration(
            color: edition.paper,
            border: Border.all(
              color: selected ? outline : Colors.transparent,
              width: 2,
              strokeAlign: BorderSide.strokeAlignOutside,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x80000000),
                blurRadius: 18,
                spreadRadius: -8,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Édition',
                style: AppType.smallCaps(
                  size: 11,
                  trackingEm: 0.18,
                  color: edition.ink.withValues(alpha: 0.75),
                ),
              ),
              Text(
                edition.no,
                style: AppType.serif(
                  size: 44,
                  weight: 300,
                  height: 0.9,
                  tabular: true,
                  color: edition.ink,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      edition.name,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.serif(
                        size: 17,
                        italic: true,
                        height: 1,
                        color: edition.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: edition.accent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchiveRow extends StatelessWidget {
  const _ArchiveRow({
    required this.edition,
    required this.title,
    required this.sub,
    required this.glyph,
    required this.onTap,
  });

  final Edition edition;
  final String title;
  final String sub;
  final String glyph;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return HairlineRow(
      edition: edition,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: '$title ',
                style: AppType.serif(size: 24, color: edition.ink),
                children: [
                  TextSpan(
                    text: sub,
                    style: AppType.serif(
                      size: 15,
                      italic: true,
                      color: edition.inkAt(60),
                    ),
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          Text(glyph, style: AppType.serif(size: 22, color: edition.ink)),
        ],
      ),
    );
  }
}
