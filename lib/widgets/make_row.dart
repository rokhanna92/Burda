import 'package:flutter/material.dart';

import '../models/date_label.dart';
import '../models/magazine.dart';
import '../models/make.dart';
import '../theme/edition.dart';
import '../theme/typography.dart';
import 'page_furniture.dart';
import 'photo_tile.dart';

/// One line of the journal: what it is, where the pattern came from, and where
/// it has got to.
///
/// The same row prints on the Makes screen and on an issue, which is why the
/// issue it came from is passed in rather than looked up: on the issue's own
/// page, naming the issue would be repeating the page it is printed on.
class MakeRow extends StatelessWidget {
  const MakeRow({
    super.key,
    required this.edition,
    required this.make,
    required this.magazine,
    required this.onTap,
  });

  final Edition edition;
  final Make make;

  /// Null to leave the issue out of the line.
  final Magazine? magazine;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = make.subtitle(magazine);

    return HairlineRow(
      edition: edition,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (make.hasPhotos) ...[
            SizedBox(
              width: 44,
              height: 56,
              child: PhotoTile(edition: edition, path: make.photos.first),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Text.rich(
              TextSpan(
                text: make.name,
                style: AppType.serif(size: 24, color: edition.ink),
                children: [
                  if (subtitle.isNotEmpty)
                    TextSpan(
                      text: '  $subtitle',
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
          if (_trailing(edition) case final trailing?) ...[
            const SizedBox(width: 10),
            trailing,
          ],
        ],
      ),
    );
  }

  /// Under way prints where it has got to, since cutting and sewing differ.
  /// Queued prints nothing, because the heading above already said it. Made
  /// prints the day it was finished, when the row carries one.
  Widget? _trailing(Edition edition) {
    if (make.status.isUnderway) {
      return Text(
        make.status.label,
        style: AppType.smallCaps(
          size: 12,
          trackingEm: 0.14,
          color: edition.accent,
        ),
      );
    }
    if (make.status.isDone && make.finishedOn != null) {
      return Text(
        dayMonthYear(make.finishedOn!),
        style: AppType.serif(size: 13, italic: true, color: edition.inkAt(60)),
      );
    }
    return null;
  }
}
