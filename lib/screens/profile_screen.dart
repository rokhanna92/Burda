import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_version.dart';
import '../models/collector_rank.dart';
import '../models/date_label.dart';
import '../models/endgame.dart';
import '../models/note_provider.dart';
import '../providers/contents_provider.dart';
import '../providers/magazine_provider.dart';
import '../providers/make_provider.dart';
import '../providers/measure_provider.dart';
import '../providers/theme_provider.dart';
import '../services/data_transfer_service.dart';
import '../services/photo_relink_service.dart';
import '../services/update_service.dart';
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

  /// What the update row says under its title.
  String _updateNote = 'version $kAppVersion';
  bool _updating = false;

  /// Looks for a newer build, fetches it and hands it to Android, all from one
  /// tap.
  ///
  /// Every step reports into the row itself rather than a sheet, so the whole
  /// thing reads as one line of the archive the way the design draws the rest.
  Future<void> _update() async {
    if (_updating) return;
    final nav = BurdaNav.of(context);
    setState(() {
      _updating = true;
      _updateNote = 'looking for a newer build';
    });

    try {
      switch (await UpdateService.check()) {
        case NoUpdate():
          setState(() => _updateNote = 'this is the newest build');
          nav.showToast('Already up to date');
          return;

        case UpdateWithoutApk(:final tag):
          // Published, but with no apk on it. Saying "up to date" here would
          // send him looking at the app when the answer is on the release.
          setState(() => _updateNote = '$tag has no apk attached to it');
          nav.showToast('$tag carries no apk');
          return;

        case UpdateAvailable(:final release):
          // Anything left from a previous update goes first.
          await UpdateService.tidy();

          var shown = -1;
          final apk = await UpdateService.download(
            release,
            onProgress: (progress) {
              final percent = (progress * 100).round();
              // Only when the whole number moves, rather than every chunk.
              if (percent == shown || !mounted) return;
              shown = percent;
              setState(
                () => _updateNote = 'downloading ${release.tag} · $percent%',
              );
            },
          );

          if (!mounted) return;
          setState(() => _updateNote = '${release.tag} ready to install');
          await UpdateService.install(apk);
      }
    } on SocketException {
      if (mounted) setState(() => _updateNote = 'could not reach GitHub');
      nav.showToast('No connection');
    } catch (error) {
      if (mounted) setState(() => _updateNote = 'version $kAppVersion');
      nav.showToast('Update failed');
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  /// What an import says it brought back, naming only what it actually found.
  static String _restored(int issues, int pages, int makes) {
    final parts = [
      '$issues issues',
      if (pages > 0) '$pages pages',
      if (makes > 0) '$makes makes',
    ];
    return '${parts.join(' and ')} restored';
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    final nav = BurdaNav.of(context);
    try {
      // The settings are the one part that has to be read from the database
      // rather than from memory, so they are fetched before anything else
      // touches the context.
      final settings = await context.read<MeasureProvider>().exportSettings();
      if (!mounted) return;

      final bytes = DataTransferService.encode(
        DataTransferService.bundle(
          magazines: context.read<MagazineProvider>().toExportJson(),
          contents: context.read<ContentsProvider>().toExportJson(),
          makes: context.read<MakeProvider>().toExportJson(),
          notes: context.read<NoteProvider>().toExportJson(),
          settings: settings,
        ),
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
      final decoded = await DataTransferService.pickImport();
      if (decoded == null) {
        nav.showToast('No file chosen');
        return;
      }
      if (!mounted) return;
      final file = DataTransferService.read(decoded);
      final magazines = context.read<MagazineProvider>();
      final contents = context.read<ContentsProvider>();
      final makes = context.read<MakeProvider>();

      final count = await magazines.import(file.magazines);
      final pages = await contents.import(file.contents);
      final made = await makes.import(file.makes);
      if (mounted) await context.read<NoteProvider>().import(file.notes);
      if (mounted) {
        await context.read<MeasureProvider>().import(file.settings);
      }
      nav.showToast(_restored(count, pages, made));

      await _restorePhotos(magazines, contents, makes, nav);

      if (magazines.endgame is Finished) {
        final first = await magazines.markComplete();
        nav.celebrate(
          first ? 'The whole collection. Every issue.' : 'Every issue again ♥',
        );
      }
    } catch (error) {
      nav.showToast('Could not read that file');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Points the imported photo paths at files that exist on this phone.
  ///
  /// An export carries absolute paths belonging to the phone and the package
  /// name it was written on, and the photos themselves are not in the file. So:
  /// repair what can be repaired silently, then, only if something is still
  /// missing, ask where the photos were put and copy them in.
  ///
  /// The vault photos, the chosen covers, the photographed pages and the make
  /// photos are all repaired in one pass and counted together, because she is
  /// answering one question, "where are the pictures", and being asked it twice
  /// would be being asked it twice about the same folder.
  Future<void> _restorePhotos(
    MagazineProvider magazines,
    ContentsProvider contents,
    MakeProvider makes,
    BurdaNav nav,
  ) async {
    var report = await _repairAll(magazines, contents, makes);

    if (!report.anyLost) {
      if (report.recovered > 0) {
        nav.showToast('${report.recovered} photos found again');
      }
      return;
    }

    final folder = await FilePicker.getDirectoryPath(
      dialogTitle: 'Where are the photos from the old app?',
    );
    if (folder == null || !mounted) {
      nav.showToast('${report.lost} photos not found');
      return;
    }

    report = await _repairAll(
      magazines,
      contents,
      makes,
      sourceFolder: Directory(folder),
    );

    nav.showToast(
      report.anyLost
          ? '${report.recovered} photos restored, ${report.lost} still missing'
          : '${report.recovered} photos restored',
    );
  }

  /// One pass over everything with a path in it.
  Future<RelinkReport> _repairAll(
    MagazineProvider magazines,
    ContentsProvider contents,
    MakeProvider makes, {
    Directory? sourceFolder,
  }) async {
    final (issueChanges, issueReport) = await PhotoRelinkService.repair(
      magazines.magazines,
      sourceFolder: sourceFolder,
    );
    await magazines.applyRelink(issueChanges);

    final (pageChanges, pageReport) = await PhotoRelinkService.repairPages(
      contents.entries,
      sourceFolder: sourceFolder,
    );
    await contents.applyRelink(pageChanges);

    final (makeChanges, makeReport) = await PhotoRelinkService.repairMakes(
      makes.makes,
      sourceFolder: sourceFolder,
    );
    await makes.applyRelink(makeChanges);

    return issueReport + pageReport + makeReport;
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
                if (context.watch<MagazineProvider>().endgame case Finished(
                  :final completedOn,
                )) ...[
                  const SizedBox(height: 14),
                  _FinishedCard(
                    edition: edition,
                    line: context.read<MagazineProvider>().mainLine,
                    completedOn: completedOn,
                  ),
                ],
                const SizedBox(height: 30),
                SectionHeader(
                  'Measurements',
                  edition: edition,
                  note: 'for when you cut',
                ),
                const SizedBox(height: 4),
                _ArchiveRow(
                  edition: edition,
                  title: 'Your measurements',
                  sub: 'bust, waist, hip, and the size they make',
                  glyph: '→',
                  onTap: () => nav.push(const MeasurePage()),
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
                  // Says plainly that the pictures are not in the file: she
                  // will have photographed two hundred contents pages by then,
                  // and a backup that looks complete and is not is worse than
                  // one that tells the truth.
                  sub:
                      'a .json you can keep anywhere, photos stay on the phone',
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
                  title: 'Update Burda Style',
                  sub: _updateNote,
                  glyph: '↻',
                  onTap: _updating ? null : _update,
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

/// The record of a finished collection, set like the rank card above it.
///
/// It is the one thing on this screen that cannot be undone by a tap: giving an
/// issue up takes the card away, and taking it back brings it back carrying the
/// original date.
class _FinishedCard extends StatelessWidget {
  const _FinishedCard({
    required this.edition,
    required this.line,
    required this.completedOn,
  });

  final Edition edition;
  final MainLine line;
  final DateTime? completedOn;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    decoration: BoxDecoration(border: Border.all(color: edition.ink)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'The collection',
          style: AppType.smallCaps(
            size: 13,
            trackingEm: 0.2,
            color: edition.accent,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Complete',
          style: AppType.serif(
            size: 34,
            weight: 500,
            height: 1.05,
            color: edition.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${line.owned} issues, ${line.years.first} to ${line.years.last}',
          style: AppType.serif(
            size: 15,
            italic: true,
            color: edition.inkAt(65),
          ),
        ),
        if (completedOn case final day?) ...[
          const SizedBox(height: 10),
          Text(
            'Finished ${dayMonthYear(day)}',
            style: AppType.smallCaps(
              size: 12,
              trackingEm: 0.18,
              color: edition.inkAt(55),
            ),
          ),
        ],
      ],
    ),
  );
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
