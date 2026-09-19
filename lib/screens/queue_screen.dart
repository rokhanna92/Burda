import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/magazine.dart';
import '../models/make.dart';
import '../providers/magazine_provider.dart';
import '../providers/make_provider.dart';
import '../shell/burda_nav.dart';
import '../theme/edition.dart';
import '../theme/typography.dart';
import '../widgets/cover_tile.dart';
import '../widgets/page_furniture.dart';

/// What to make next, in her order.
///
/// What "Missing" used to be on the index: a number that moves. It is filled
/// from issues, which is where she decides, so there is no add button here.
class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key, required this.edition});

  final Edition edition;

  @override
  Widget build(BuildContext context) {
    final makes = context.watch<MakeProvider>();
    final magazines = context.watch<MagazineProvider>();
    final nav = BurdaNav.of(context);
    final queue = makes.queued;

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
              Flexible(child: ScreenTitle('Sew queue', edition: edition)),
              const SizedBox(width: 10),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${queue.length} to make',
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.serif(
                      size: 16,
                      italic: true,
                      color: edition.inkAt(65),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (queue.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Text(
                'Nothing waiting.\n'
                'Open an issue and put it in the sew queue.',
                textAlign: TextAlign.center,
                style: AppType.serif(
                  size: 19,
                  italic: true,
                  height: 1.4,
                  color: edition.inkAt(60),
                ),
              ),
            )
          else ...[
            const SizedBox(height: 22),
            // The gesture is taught in the slot the kit already keeps for it.
            SectionHeader(
              'Next first',
              edition: edition,
              note: '↑ moves one up',
            ),
            const SizedBox(height: 4),
            for (final (index, make) in queue.indexed)
              _QueueRow(
                key: ValueKey(make.id),
                edition: edition,
                make: make,
                magazine: make.magazineId == null
                    ? null
                    : magazines.byId(make.magazineId!),
                position: index + 1,
                canMoveUp: index > 0,
                onOpen: make.magazineId == null
                    ? () => nav.push(MakePage(make.id))
                    : () => nav.push(IssuePage(make.magazineId!)),
                onUp: () => makes.moveUp(make.id),
                onRemove: () async {
                  await makes.unqueue(make.id);
                  nav.showToast('Taken out of the queue');
                },
              ),
          ],
        ],
      ),
    );
  }
}

/// One waiting make: where it sits, what it came out of, and the two glyphs
/// that move it or take it out.
class _QueueRow extends StatelessWidget {
  const _QueueRow({
    super.key,
    required this.edition,
    required this.make,
    required this.magazine,
    required this.position,
    required this.canMoveUp,
    required this.onOpen,
    required this.onUp,
    required this.onRemove,
  });

  final Edition edition;
  final Make make;
  final Magazine? magazine;
  final int position;
  final bool canMoveUp;
  final VoidCallback onOpen;
  final VoidCallback onUp;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return HairlineRow(
      edition: edition,
      onTap: onOpen,
      verticalPadding: 12,
      child: Row(
        children: [
          SizedBox(
            width: 28,
            // What makes a move legible: 03 becomes 02.
            child: Text(
              position.toString().padLeft(2, '0'),
              style: AppType.serif(
                size: 13,
                trackingEm: 0.12,
                tabular: true,
                color: edition.accent,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            height: 54,
            child: magazine == null
                ? ColoredBox(color: edition.tint)
                : CoverTile(
                    magazine: magazine!,
                    edition: edition,
                    numeralSize: 20,
                    depth: CoverDepth.flat,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  magazine == null
                      ? 'Something to make'
                      : 'No. ${magazine!.issue} · ${magazine!.year}',
                  overflow: TextOverflow.ellipsis,
                  style: AppType.serif(
                    size: 22,
                    weight: 500,
                    height: 1.1,
                    color: edition.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  make.patternNo.isEmpty
                      ? 'no pattern noted yet'
                      : 'Pattern ${make.patternNo}',
                  overflow: TextOverflow.ellipsis,
                  style: AppType.serif(
                    size: 15,
                    italic: true,
                    color: edition.inkAt(65),
                  ),
                ),
              ],
            ),
          ),
          // A fixed box either way, so the crosses stay in a column whether or
          // not there is an arrow beside them.
          SizedBox(
            width: 30,
            child: canMoveUp
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onUp,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        '↑',
                        textAlign: TextAlign.center,
                        style: AppType.serif(size: 22, color: edition.ink),
                      ),
                    ),
                  )
                : null,
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRemove,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 0, 10),
              child: Text(
                '×',
                style: AppType.serif(
                  size: 24,
                  height: 1,
                  color: edition.inkAt(50),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
