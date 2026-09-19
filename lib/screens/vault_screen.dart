import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/magazine_provider.dart';
import '../shell/burda_nav.dart';
import '../theme/edition.dart';
import '../theme/typography.dart';
import '../widgets/page_furniture.dart';
import '../widgets/photo_tile.dart';

/// Every photo in the collection in one place, each tapping through to the
/// issue it came from.
class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key, required this.edition});

  final Edition edition;

  @override
  Widget build(BuildContext context) {
    final photos = context.watch<MagazineProvider>().vaultPhotos;
    final nav = BurdaNav.of(context);

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
              ScreenTitle('Vault', edition: edition),
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
                'Open an issue and add a photo of a pattern you sewed.',
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
                for (final photo in photos)
                  PressScale(
                    key: ValueKey(photo.path),
                    onTap: () => nav.push(IssuePage(photo.magazine.id)),
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
                          'No. ${photo.magazine.issue} · ${photo.magazine.year}',
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
              ],
            ),
          ],
        ],
      ),
    );
  }
}
