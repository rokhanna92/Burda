import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/contents_entry.dart';
import '../models/garment_tag.dart';
import '../providers/contents_provider.dart';
import '../shell/burda_nav.dart';
import '../theme/edition.dart';
import '../theme/typography.dart';
import '../widgets/page_furniture.dart';
import '../widgets/tag_chips.dart';

/// Reading an issue's photographed pages, full screen.
///
/// Not a [BurdaPage]. A page on the shell's stack slides in under the nav bar
/// and scrolls with the rest of the screen, and both are wrong here: a contents
/// spread wants every pixel, and a pinch should not be fighting a vertical
/// scroll for the same drag. So the reader goes where the sheet goes, over
/// everything, in the shell's own stack.
class ContentsReader extends StatefulWidget {
  const ContentsReader({
    super.key,
    required this.edition,
    required this.magazineId,
    this.startAt = 0,
  });

  final Edition edition;
  final String magazineId;

  /// Which page was tapped.
  final int startAt;

  @override
  State<ContentsReader> createState() => _ContentsReaderState();
}

class _ContentsReaderState extends State<ContentsReader> {
  late final PageController _controller = PageController(
    initialPage: widget.startAt,
  );
  late int _index = widget.startAt;

  /// True while the page on show is pinched in, which is when the PageView has
  /// to let go of the horizontal drag.
  bool _zoomed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _remove(ContentsEntry entry) async {
    final nav = BurdaNav.of(context);
    await context.read<ContentsProvider>().removePage(entry.id);
    nav.showToast('Page removed');
  }

  @override
  Widget build(BuildContext context) {
    final edition = widget.edition;
    final nav = BurdaNav.of(context);
    final pages = context.watch<ContentsProvider>().forIssue(widget.magazineId);

    // The last page was removed out from under us, so there is nothing left to
    // read. Closing during a build is not allowed, so it waits for the frame.
    if (pages.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => nav.closeReader());
      return const SizedBox.shrink();
    }

    final index = _index.clamp(0, pages.length - 1);
    final entry = pages[index];

    return GestureDetector(
      // Swallows taps and drags so neither reaches the issue underneath, the
      // way the sheet's scrim does.
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: ColoredBox(
        color: edition.paper,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    BackLink(edition: edition, onTap: nav.closeReader),
                    Text(
                      pages.length == 1
                          ? 'one page'
                          : 'page ${index + 1} of ${pages.length}',
                      style: AppType.serif(
                        size: 15,
                        italic: true,
                        color: edition.inkAt(60),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    physics: _zoomed
                        ? const NeverScrollableScrollPhysics()
                        : const PageScrollPhysics(),
                    itemCount: pages.length,
                    onPageChanged: (page) => setState(() {
                      _index = page;
                      _zoomed = false;
                    }),
                    itemBuilder: (context, at) => _Page(
                      key: ValueKey(pages[at].id),
                      edition: edition,
                      entry: pages[at],
                      onZoom: (zoomed) {
                        // The PageView builds the neighbour mid drag, and that
                        // neighbour is never zoomed. Without this the pan turns
                        // into a page turn halfway through.
                        if (at != index || zoomed == _zoomed) return;
                        setState(() => _zoomed = zoomed);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'On this page',
                  style: AppType.smallCaps(
                    size: 13,
                    trackingEm: 0.22,
                    color: edition.ink,
                  ),
                ),
                const SizedBox(height: 10),
                TagChips(
                  edition: edition,
                  tags: GarmentTag.values,
                  picked: entry.tags,
                  onToggle: (tag) =>
                      context.read<ContentsProvider>().toggleTag(entry.id, tag),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _remove(entry),
                  child: Text(
                    'Remove this page',
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
          ),
        ),
      ),
    );
  }
}

/// One photograph, pinchable.
class _Page extends StatefulWidget {
  const _Page({
    super.key,
    required this.edition,
    required this.entry,
    required this.onZoom,
  });

  final Edition edition;
  final ContentsEntry entry;
  final ValueChanged<bool> onZoom;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  final TransformationController _zoom = TransformationController();

  @override
  void initState() {
    super.initState();
    _zoom.addListener(_report);
  }

  @override
  void dispose() {
    _zoom
      ..removeListener(_report)
      ..dispose();
    super.dispose();
  }

  /// A hair over 1, so floating point drift at rest does not read as a pinch.
  void _report() => widget.onZoom(_zoom.value.getMaxScaleOnAxis() > 1.01);

  @override
  Widget build(BuildContext context) {
    final path = widget.entry.path;

    return InteractiveViewer(
      transformationController: _zoom,
      minScale: 1,
      maxScale: 4,
      child: Center(
        child: path.isEmpty
            ? _missing()
            : Image.file(
                File(path),
                // Contain rather than cover: a cropped contents page is a
                // contents page you cannot read.
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => _missing(),
              ),
      ),
    );
  }

  Widget _missing() => Padding(
    padding: const EdgeInsets.all(24),
    child: Text(
      'That photograph is not on this phone any more.',
      textAlign: TextAlign.center,
      style: AppType.serif(
        size: 18,
        italic: true,
        height: 1.4,
        color: widget.edition.inkAt(60),
      ),
    ),
  );
}
