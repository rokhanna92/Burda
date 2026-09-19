import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/magazine.dart';
import '../models/make.dart';
import '../providers/contents_provider.dart';
import '../providers/magazine_provider.dart';
import '../providers/make_provider.dart';
import '../services/image_storage_service.dart';
import '../shell/burda_nav.dart';
import '../theme/edition.dart';
import '../theme/typography.dart';
import '../widgets/page_furniture.dart';

/// Asking before an issue is taken out of the index for good.
class ConfirmSheet extends StatelessWidget {
  const ConfirmSheet({
    super.key,
    required this.edition,
    required this.magazine,
  });

  final Edition edition;
  final Magazine magazine;

  Future<void> _remove(BuildContext context) async {
    final nav = BurdaNav.of(context);
    final magazines = context.read<MagazineProvider>();
    final contents = context.read<ContentsProvider>();

    // The photos go with it, rather than being orphaned on disk.
    for (final path in magazine.uploadedImages) {
      await ImageStorageService.delete(path);
    }
    if (magazine.hasFileCover) await ImageStorageService.delete(magazine.image);

    // As do the photographs of its own pages, which is the other half of what
    // "its photos go with it" promises below.
    await contents.removeIssue(magazine.id);

    await magazines.deleteMagazine(magazine.id);

    nav.closeSheet();
    nav.back();
    nav.showToast('No. ${magazine.issue} / ${magazine.year} removed');
  }

  @override
  Widget build(BuildContext context) {
    final nav = BurdaNav.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        Text(
          'Remove No. ${magazine.issue} / ${magazine.year} from the index?',
          textAlign: TextAlign.center,
          style: AppType.serif(
            size: 30,
            weight: 500,
            height: 1.1,
            color: edition.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Its photos and condition go with it.',
          textAlign: TextAlign.center,
          style: AppType.serif(
            size: 16,
            italic: true,
            color: edition.inkAt(65),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: BurdaButton(
                edition: edition,
                label: 'Keep',
                onTap: nav.closeSheet,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _RemoveButton(
                edition: edition,
                onTap: () => _remove(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Asking before a make is taken out of the journal for good.
class ConfirmMakeSheet extends StatelessWidget {
  const ConfirmMakeSheet({
    super.key,
    required this.edition,
    required this.make,
  });

  final Edition edition;
  final Make make;

  Future<void> _remove(BuildContext context) async {
    final nav = BurdaNav.of(context);
    final makes = context.read<MakeProvider>();

    // Its own photos go with it. One brought over from an issue was moved, not
    // copied, so this is the only row that holds it.
    for (final path in make.photos) {
      await ImageStorageService.delete(path);
    }

    await makes.deleteMake(make.id);

    nav.closeSheet();
    nav.back();
    nav.showToast('${make.name} removed from the journal');
  }

  @override
  Widget build(BuildContext context) {
    final nav = BurdaNav.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        Text(
          'Remove this make from the journal?',
          textAlign: TextAlign.center,
          style: AppType.serif(
            size: 30,
            weight: 500,
            height: 1.1,
            color: edition.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${make.name}, with its photos and its dates.',
          textAlign: TextAlign.center,
          style: AppType.serif(
            size: 16,
            italic: true,
            color: edition.inkAt(65),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: BurdaButton(
                edition: edition,
                label: 'Keep',
                onTap: nav.closeSheet,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _RemoveButton(
                edition: edition,
                onTap: () => _remove(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The one button in the app printed in the accent rather than the ink.
class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.edition, required this.onTap});

  final Edition edition;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PressScale(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(15),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: edition.accent,
        border: Border.all(color: edition.accent),
      ),
      child: Text(
        'Remove',
        style: AppType.smallCaps(
          size: 16,
          trackingEm: 0.14,
          color: edition.onAccent,
        ),
      ),
    ),
  );
}
