import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/date_label.dart';
import '../models/magazine.dart';
import '../models/make.dart';
import '../providers/magazine_provider.dart';
import '../providers/make_provider.dart';
import '../services/image_storage_service.dart';
import '../shell/burda_nav.dart';
import '../theme/edition.dart';
import '../theme/typography.dart';
import '../widgets/page_furniture.dart';
import '../widgets/photo_tile.dart';

/// One make: what it is, how far along, what she wrote down, and the photos.
class MakeScreen extends StatefulWidget {
  const MakeScreen({super.key, required this.edition, required this.id});

  final Edition edition;
  final String id;

  @override
  State<MakeScreen> createState() => _MakeScreenState();
}

class _MakeScreenState extends State<MakeScreen> {
  bool _picking = false;

  /// True while the grid is offering the issue's loose photos instead of the
  /// make's own.
  bool _choosing = false;

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
      final path = await ImageStorageService.saveMakePhoto(
        makeId: widget.id,
        sourcePath: picked.path,
      );
      if (!mounted) return;
      await context.read<MakeProvider>().addPhoto(widget.id, path);
      nav.showToast('Photo added to this make');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _removePhoto(String path) async {
    final nav = BurdaNav.of(context);
    await ImageStorageService.delete(path);
    if (!mounted) return;
    await context.read<MakeProvider>().removePhoto(widget.id, path);
    nav.showToast('Photo removed from this make');
  }

  /// Moves one loose photo of the issue onto this make.
  ///
  /// The file does not move. Nothing works out who owns a photo from the folder
  /// it sits in, the path is stored in full, and moving it is the one step here
  /// that can fail halfway and take a photograph with it. Added before removed,
  /// so a crash in between shows it twice rather than losing it.
  Future<void> _bringOver(String magazineId, String path) async {
    final nav = BurdaNav.of(context);
    final makes = context.read<MakeProvider>();
    final magazines = context.read<MagazineProvider>();

    await makes.addPhoto(widget.id, path);
    await magazines.removeUploadedImage(magazineId, path);
    if (!mounted) return;
    setState(() => _choosing = false);
    nav.showToast('Brought over from the issue');
  }

  Future<void> _setStatus(MakeStatus status) async {
    final nav = BurdaNav.of(context);
    await context.read<MakeProvider>().setStatus(widget.id, status);
    if (status.isDone) nav.rain();
    nav.showToast(switch (status) {
      MakeStatus.queued => 'Back in the queue',
      MakeStatus.cutting => 'Cutting out',
      MakeStatus.sewing => 'Under the needle',
      MakeStatus.done => 'Finished ♥',
    });
  }

  /// The dates it has collected, as one line.
  static String _stamps(Make make) => [
    'queued ${dayMonthYear(make.queuedOn)}',
    if (make.startedOn case final started?) 'started ${dayMonthYear(started)}',
    if (make.finishedOn case final finished?)
      'finished ${dayMonthYear(finished)}',
  ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final edition = widget.edition;
    final nav = BurdaNav.of(context);
    final make = context.select<MakeProvider, Make?>(
      (makes) => makes.byId(widget.id),
    );

    // Removed out from under us, which the shell will pop past in a moment.
    if (make == null) return const SizedBox.shrink();

    final magazine = make.magazineId == null
        ? null
        : context.select<MagazineProvider, Magazine?>(
            (magazines) => magazines.byId(make.magazineId!),
          );
    final loose = magazine?.uploadedImages ?? const <String>[];

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
          ScreenTitle(make.name, edition: edition),
          if (magazine != null) ...[
            const SizedBox(height: 4),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => nav.push(IssuePage(magazine.id)),
              child: Text(
                'from No. ${magazine.issue} / ${magazine.year} →',
                style: AppType.serif(
                  size: 17,
                  italic: true,
                  color: edition.accent,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          _StatusRow(
            edition: edition,
            current: make.status,
            onPick: _setStatus,
          ),
          const SizedBox(height: 10),
          Text(
            _stamps(make),
            style: AppType.serif(
              size: 14,
              italic: true,
              color: edition.inkAt(60),
            ),
          ),
          const SizedBox(height: 26),
          SectionHeader(
            'The pattern',
            edition: edition,
            trailing: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => nav.openSheet(BurdaSheet.make),
              child: Text(
                'edit →',
                textAlign: TextAlign.end,
                style: AppType.serif(
                  size: 15,
                  italic: true,
                  color: edition.accent,
                ),
              ),
            ),
          ),
          if (make.isBlank)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Nothing written down yet.',
                style: AppType.serif(
                  size: 16,
                  italic: true,
                  color: edition.inkAt(60),
                ),
              ),
            )
          else ...[
            if (make.patternNo.isNotEmpty)
              _PatternRow(
                edition: edition,
                label: 'Pattern',
                value: make.patternNo,
              ),
            if (make.size.isNotEmpty)
              _PatternRow(edition: edition, label: 'Size', value: make.size),
            if (make.fabric.isNotEmpty)
              _PatternRow(
                edition: edition,
                label: 'Fabric',
                value: make.fabric,
              ),
            if (make.garment case final garment?)
              _PatternRow(
                edition: edition,
                label: 'Garment',
                value: garment.one,
              ),
          ],
          if (make.notes.isNotEmpty) ...[
            const SizedBox(height: 26),
            SectionHeader('Notes', edition: edition),
            const SizedBox(height: 10),
            Text(
              make.notes,
              style: AppType.serif(
                size: 17,
                height: 1.4,
                color: edition.inkAt(78),
              ),
            ),
          ],
          const SizedBox(height: 26),
          SectionHeader(
            'Photos',
            edition: edition,
            note: _choosing
                ? 'tap one to bring it over'
                : '${make.photos.length} of this make',
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: _choosing
                ? [
                    for (final (index, path) in loose.indexed)
                      CoverIn(
                        key: ValueKey('loose:$path'),
                        order: index,
                        duration: const Duration(milliseconds: 350),
                        child: PressScale(
                          scale: 0.95,
                          onTap: () => _bringOver(magazine!.id, path),
                          child: PhotoTile(edition: edition, path: path),
                        ),
                      ),
                  ]
                : [
                    for (final (index, path) in make.photos.indexed)
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
                    AddPhotoTile(
                      edition: edition,
                      onTap: _picking ? null : _addPhoto,
                    ),
                    if (loose.isNotEmpty)
                      AddPhotoTile(
                        edition: edition,
                        glyph: '↓',
                        label: 'From the issue',
                        onTap: () => setState(() => _choosing = true),
                      ),
                  ],
          ),
          if (_choosing) ...[
            const SizedBox(height: 14),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _choosing = false),
              child: Text(
                'Never mind',
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
          const SizedBox(height: 34),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => nav.openSheet(BurdaSheet.confirm),
            child: Text(
              'Remove this make from the journal',
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

/// The four stages, the one it is on filled in.
class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.edition,
    required this.current,
    required this.onPick,
  });

  final Edition edition;
  final MakeStatus current;
  final ValueChanged<MakeStatus> onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final status in MakeStatus.values) ...[
          if (status != MakeStatus.values.first) const SizedBox(width: 6),
          Expanded(
            child: PressScale(
              scale: 0.93,
              onTap: () => onPick(status),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: status == current ? edition.ink : Colors.transparent,
                  border: Border.all(color: edition.inkAt(35)),
                ),
                child: Text(
                  status.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.smallCaps(
                    size: 13,
                    trackingEm: 0.12,
                    color: status == current ? edition.paper : edition.ink,
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

/// A label on the left and what she wrote on the right.
class _PatternRow extends StatelessWidget {
  const _PatternRow({
    required this.edition,
    required this.label,
    required this.value,
  });

  final Edition edition;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => HairlineRow(
    edition: edition,
    verticalPadding: 12,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          label,
          style: AppType.smallCaps(
            size: 13,
            trackingEm: 0.18,
            color: edition.inkAt(60),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: AppType.serif(size: 19, color: edition.ink),
          ),
        ),
      ],
    ),
  );
}
