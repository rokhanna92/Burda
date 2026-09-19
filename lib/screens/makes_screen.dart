import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/make.dart';
import '../providers/magazine_provider.dart';
import '../providers/make_provider.dart';
import '../shell/burda_nav.dart';
import '../theme/edition.dart';
import '../theme/typography.dart';
import '../widgets/make_row.dart';
import '../widgets/page_furniture.dart';

/// The journal: what is on the go, what is waiting, and what she has made.
///
/// Grouped by status rather than filtered by tabs. Grouping needs no state and
/// no extra tap, and it puts the two garments waiting on her at the top of the
/// page, which is the reason to open this on a Tuesday.
class MakesScreen extends StatelessWidget {
  const MakesScreen({super.key, required this.edition});

  final Edition edition;

  @override
  Widget build(BuildContext context) {
    final makes = context.watch<MakeProvider>();
    final magazines = context.watch<MagazineProvider>();
    final nav = BurdaNav.of(context);

    Widget group(String label, String note, List<Make> rows) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 22),
        SectionHeader(label, edition: edition, note: note),
        for (final make in rows)
          MakeRow(
            key: ValueKey(make.id),
            edition: edition,
            make: make,
            magazine: make.magazineId == null
                ? null
                : magazines.byId(make.magazineId!),
            onTap: () => nav.push(MakePage(make.id)),
          ),
      ],
    );

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
              Flexible(child: ScreenTitle('Makes', edition: edition)),
              BurdaButton(
                edition: edition,
                label: '+ New make',
                filled: true,
                size: 15,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                pressScale: 0.96,
                onTap: () => nav.openSheet(BurdaSheet.make),
              ),
            ],
          ),
          if (makes.count == 0)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Text(
                'Nothing made yet. Start one here, or from an issue.',
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
            if (makes.onTheGo.isNotEmpty)
              group(
                'On the go',
                '${makes.onTheGo.length} under way',
                makes.onTheGo,
              ),
            if (makes.queued.isNotEmpty)
              group('Queued', '${makes.queued.length} waiting', makes.queued),
            if (makes.made.isNotEmpty)
              group('Made', '${makes.made.length} finished', makes.made),
          ],
          const SizedBox(height: 30),
          SectionHeader(
            'The vault',
            edition: edition,
            note: '${makes.photoCount + magazines.vaultCount} photos in all',
          ),
          HairlineRow(
            edition: edition,
            onTap: () => nav.push(const VaultPage()),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: 'Every photo ',
                      style: AppType.serif(size: 24, color: edition.ink),
                      children: [
                        TextSpan(
                          text: 'from makes and from issues',
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
                Text('→', style: AppType.serif(size: 22, color: edition.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
