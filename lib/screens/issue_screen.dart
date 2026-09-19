import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/magazine.dart';
import '../providers/magazine_provider.dart';
import '../services/image_storage_service.dart';
import '../shell/burda_nav.dart';
import '../shell/collection_actions.dart';
import '../theme/edition.dart';
import '../theme/motion.dart';
import '../theme/typography.dart';
import '../widgets/cover_tile.dart';
import '../widgets/page_furniture.dart';
import '../widgets/photo_tile.dart';

/// One issue: its cover, whether it is yours, what state it is in, and the
/// photos of what you made from it.
class IssueScreen extends StatefulWidget {
  const IssueScreen({super.key, required this.edition, required this.id});

  final Edition edition;
  final String id;

  @override
  State<IssueScreen> createState() => _IssueScreenState();
}

class _IssueScreenState extends State<IssueScreen> {
  bool _picking = false;

  Future<void> _addPhoto() async {
    if (_picking) return;
    setState(() => _picking = true);
    final nav = BurdaNav.of(context);
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) {
        nav.showToast('No photo chosen');
        return;
      }
      final path = await ImageStorageService.save(
        magazineId: widget.id,
        sourcePath: picked.path,
      );
      if (!mounted) return;
      await context.read<MagazineProvider>().addUploadedImage(widget.id, path);
      nav.showToast('Photo added to the vault');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _removePhoto(String path) async {
    final nav = BurdaNav.of(context);
    await ImageStorageService.delete(path);
    if (!mounted) return;
    await context.read<MagazineProvider>().removeUploadedImage(widget.id, path);
    nav.showToast('Photo removed from the vault');
  }

  Future<void> _setCondition(int score) async {
    final nav = BurdaNav.of(context);
    await context.read<MagazineProvider>().setCondition(widget.id, score);
    nav.showToast('Condition set to $score');
  }

  @override
  Widget build(BuildContext context) {
    final edition = widget.edition;
    final nav = BurdaNav.of(context);
    final magazine = context.select<MagazineProvider, Magazine?>(
      (magazines) => magazines.byId(widget.id),
    );

    // Deleted out from under us, which the shell will pop past in a moment.
    if (magazine == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: BackLink(edition: edition, onTap: nav.back),
          ),
          const SizedBox(height: 10),
          Center(
            child: _Hero(edition: edition, magazine: magazine),
          ),
          const SizedBox(height: 22),
          Text(
            'No. ${magazine.issue}',
            textAlign: TextAlign.center,
            style: AppType.serif(
              size: 44,
              weight: 500,
              trackingEm: -0.02,
              height: 1,
              color: edition.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Burda Style, ${magazine.year}',
            textAlign: TextAlign.center,
            style: AppType.serif(
              size: 19,
              italic: true,
              color: edition.inkAt(70),
            ),
          ),
          const SizedBox(height: 20),
          BurdaButton(
            edition: edition,
            label: magazine.isOwned ? 'In the collection' : 'Add to collection',
            glyph: magazine.isOwned ? '♥' : '♡',
            filled: magazine.isOwned,
            size: 17,
            trackingEm: 0.16,
            pressScale: 0.98,
            onTap: () => toggleIssueOwned(context, magazine),
          ),
          if (magazine.isOwned) ...[
            const SizedBox(height: 30),
            SectionHeader(
              'Condition',
              edition: edition,
              trailing: Text(
                magazine.conditionScore == null
                    ? 'not rated yet'
                    : '${magazine.conditionScore} · '
                          '${conditionWord(magazine.conditionScore!)}',
                style: AppType.serif(
                  size: 17,
                  italic: true,
                  color: edition.ink,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _ConditionTicks(
              edition: edition,
              score: magazine.conditionScore,
              onSet: _setCondition,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final label in ['Worn', 'Good', 'Mint'])
                  Text(
                    label,
                    style: AppType.smallCaps(
                      size: 12,
                      trackingEm: 0.14,
                      color: edition.inkAt(60),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 30),
          SectionHeader(
            'Vault',
            edition: edition,
            note: '${magazine.uploadedImages.length} photos of this issue',
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final (index, path) in magazine.uploadedImages.indexed)
                CoverIn(
                  key: ValueKey(path),
                  order: index,
                  duration: const Duration(milliseconds: 350),
                  child: PhotoTile(
                    edition: edition,
                    path: path,
                    placeholder: 'photo ${index + 1}',
                    onRemove: () => _removePhoto(path),
                  ),
                ),
              _AddPhotoTile(
                edition: edition,
                onTap: _picking ? null : _addPhoto,
              ),
            ],
          ),
          const SizedBox(height: 34),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => nav.openSheet(BurdaSheet.confirm),
            child: Text(
              'Remove this issue from the index',
              textAlign: TextAlign.center,
              style:
                  AppType.serif(
                    size: 15,
                    italic: true,
                    color: edition.inkAt(55),
                  ).copyWith(
                    decoration: TextDecoration.underline,
                    decorationColor: edition.inkAt(55),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The cover, arriving at a slight tilt as though laid on the page.
class _Hero extends StatelessWidget {
  const _Hero({required this.edition, required this.magazine});

  final Edition edition;
  final Magazine magazine;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(magazine.id),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: AppMotion.standard,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - t)),
          // Settles at -1.5 degrees rather than square, as the design leaves it.
          child: Transform.rotate(
            angle: (-4 + 2.5 * t) * 3.1415926 / 180,
            child: child,
          ),
        ),
      ),
      child: SizedBox(
        width: 196,
        height: 268,
        child: CoverTile(
          magazine: magazine,
          edition: edition,
          numeralSize: 88,
          depth: CoverDepth.hero,
          desaturate: !magazine.isOwned,
          imageOpacity: magazine.isOwned ? 1 : 0.75,
        ),
      ),
    );
  }
}

/// Ten squares filling up to the score.
class _ConditionTicks extends StatelessWidget {
  const _ConditionTicks({
    required this.edition,
    required this.score,
    required this.onSet,
  });

  final Edition edition;
  final int? score;
  final ValueChanged<int> onSet;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var n = 1; n <= 10; n++) ...[
          if (n > 1) const SizedBox(width: 6),
          Expanded(
            child: PressScale(
              scale: 0.9,
              onTap: () => onSet(n),
              child: AspectRatio(
                aspectRatio: 1,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: (score ?? 0) >= n
                        ? edition.accent
                        : Colors.transparent,
                    border: Border.all(color: edition.inkAt(40)),
                  ),
                  child: Text(
                    '$n',
                    style: AppType.serif(
                      size: 14,
                      tabular: true,
                      color: (score ?? 0) >= n ? edition.onAccent : edition.ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.edition, required this.onTap});

  final Edition edition;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: CustomPaint(
        painter: DashedBorder(colour: edition.inkAt(45)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '+',
              style: AppType.serif(
                size: 30,
                weight: 300,
                height: 1,
                color: edition.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Add photo',
              style: AppType.smallCaps(
                size: 12,
                trackingEm: 0.14,
                color: edition.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
