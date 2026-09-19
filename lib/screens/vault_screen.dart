import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/magazine_provider.dart';
import '../providers/make_provider.dart';
import '../shell/burda_nav.dart';
import '../theme/edition.dart';
import '../theme/typography.dart';
import '../widgets/page_furniture.dart';
import '../widgets/photo_tile.dart';

/// Every photo in one place, each tapping through to whatever it belongs to.
///
/// Two sources: the makes first, because what she made is the point of the
/// vault now, and then the photos still hanging off an issue, which are the
/// ones that have not found their make yet.
class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key, required this.edition});

  final Edition edition;

  @override
  Widget build(BuildContext context) {
    final loose = context.watch<MagazineProvider>().vaultPhotos;
    final made = context.watch<MakeProvider>().photos;
    final nav = BurdaNav.of(context);

    final photos = <({String path, String caption, BurdaPage page})>[
      for (final photo in made)
        (
          path: photo.path,
          caption: '${photo.make.name} · ${photo.make.sortDate.year}',
          page: MakePage(photo.make.id),
        ),
      for (final photo in loose)
        (
          path: photo.path,
          caption: 'No. ${photo.magazine.issue} · ${photo.magazine.year}',
          page: IssuePage(photo.magazine.id),
        ),
    ];

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
              Flexible(child: ScreenTitle('Vault', edition: edition)),
              const SizedBox(width: 10),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${photos.length} photos',
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
          if (photos.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Text(
                'Nothing here yet.\n'
                'Start a make, or add a photo to an issue.',
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
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.82,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final (index, photo) in photos.indexed)
                  CoverIn(
                    key: ValueKey(photo.path),
                    order: index,
                    duration: const Duration(milliseconds: 350),
                    stagger: const Duration(milliseconds: 50),
                    child: PressScale(
                      onTap: () => nav.push(photo.page),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: PhotoTile(
                              edition: edition,
                              path: photo.path,
                              placeholder: 'user photo',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            photo.caption,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.smallCaps(
                              size: 15,
                              trackingEm: 0.08,
                              color: edition.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
