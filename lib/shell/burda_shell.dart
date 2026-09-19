import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/magazine_provider.dart';
import '../providers/make_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/collection_screen.dart';
import '../screens/contents_reader.dart';
import '../screens/index_screen.dart';
import '../screens/issue_screen.dart';
import '../screens/make_screen.dart';
import '../screens/makes_screen.dart';
import '../screens/measure_screen.dart';
import '../screens/notes_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/queue_screen.dart';
import '../screens/vault_screen.dart';
import '../screens/year_screen.dart';
import '../screens/years_screen.dart';
import '../sheets/about_sheet.dart';
import '../sheets/add_sheet.dart';
import '../sheets/confirm_sheet.dart';
import '../sheets/lend_sheet.dart';
import '../sheets/make_sheet.dart';
import '../sheets/measure_sheet.dart';
import '../sheets/note_sheet.dart';
import '../sheets/rank_sheet.dart';
import '../sheets/search_sheet.dart';
import '../theme/edition.dart';
import '../theme/motion.dart';
import '../widgets/falling_hearts.dart';
import '../widgets/hearts.dart';
import '../widgets/nav_bar.dart';
import '../widgets/sheet_scaffold.dart';
import '../widgets/toast.dart';
import 'burda_nav.dart';

/// The whole app: one scrolling page area over a nav bar that never moves,
/// with the sheet, the hearts and the toast floating above both.
///
/// Sub-pages are pushed onto a stack held here rather than onto Navigator's,
/// because the design slides them in underneath the nav bar rather than over
/// it.
class BurdaShell extends StatefulWidget {
  const BurdaShell({super.key});

  @override
  State<BurdaShell> createState() => _BurdaShellState();
}

class _BurdaShellState extends State<BurdaShell> implements BurdaNav {
  NavTab _tab = NavTab.home;

  /// Which side of the collection is on show. Always starts on what is held.
  bool _showOwned = true;
  final List<BurdaPage> _stack = [];
  BurdaSheet? _sheet;

  /// The contents reader, which covers the nav bar and everything else.
  ReaderView? _reader;
  String? _toast;
  bool _hearts = false;

  /// Counts showers rather than flagging one, so claiming a second issue
  /// while the first is still falling starts a fresh one.
  int? _raining;
  Timer? _toastTimer;
  final PageStorageBucket _bucket = PageStorageBucket();

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  // BurdaNav

  @override
  void goTab(NavTab tab) => setState(() {
    _tab = tab;
    _stack.clear();
    _sheet = null;
    _reader = null;
  });

  @override
  void showCollection({required bool owned}) => setState(() {
    _tab = NavTab.collection;
    _showOwned = owned;
    _stack.clear();
    _sheet = null;
    _reader = null;
  });

  @override
  void push(BurdaPage page) => setState(() {
    _stack.add(page);
    _sheet = null;
    _reader = null;
  });

  @override
  void back() {
    if (_stack.isEmpty) return;
    setState(_stack.removeLast);
  }

  @override
  void openSheet(BurdaSheet sheet) => setState(() => _sheet = sheet);

  @override
  void closeSheet() => setState(() => _sheet = null);

  @override
  void openReader(String magazineId, {int startAt = 0}) => setState(() {
    _reader = (magazineId: magazineId, startAt: startAt);
    _sheet = null;
  });

  @override
  void closeReader() => setState(() => _reader = null);

  @override
  void showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toast = message);
    _toastTimer = Timer(AppMotion.toastLinger, () {
      if (mounted) setState(() => _toast = null);
    });
  }

  @override
  void rain() => setState(() => _raining = (_raining ?? 0) + 1);

  @override
  void celebrate(String message) {
    setState(() => _hearts = true);
    showToast(message);
  }

  // Layout

  /// The page on top: the pushed one if there is any, otherwise the tab.
  BurdaPage? get _top => _stack.isEmpty ? null : _stack.last;

  /// Identifies the visible page, so its scroll position is its own and its
  /// entrance replays when it changes.
  String get _pageKey => switch (_top) {
    null => 'tab:${_tab.name}',
    YearPage(:final year, :final series) => 'year:${series.id}:$year',
    IssuePage(:final id) => 'issue:$id',
    NotesPage() => 'notes',
    VaultPage() => 'vault',
    MakesPage() => 'makes',
    QueuePage() => 'queue',
    MeasurePage() => 'measure',
    MakePage(:final id) => 'make:$id',
  };

  /// What the sheet is holding, or null for the ones not built yet.
  Widget? _sheetContent(Edition edition) {
    switch (_sheet) {
      case null:
        return null;
      case BurdaSheet.add:
        return AddSheet(edition: edition);
      case BurdaSheet.search:
        return SearchSheet(edition: edition);
      case BurdaSheet.rank:
        final magazines = context.read<MagazineProvider>();
        return RankSheet(
          edition: edition,
          ownedCount: magazines.ownedCount,
          remaining: magazines.mainLine.missing.length,
        );
      case BurdaSheet.about:
        return AboutSheet(edition: edition);
      case BurdaSheet.note:
        return NoteSheet(edition: edition);
      case BurdaSheet.make:
        // Raised from a make to edit it, from an issue to start one there, and
        // from the journal to start one from nowhere in particular.
        return switch (_top) {
          MakePage(:final id) => MakeSheet(
            edition: edition,
            make: context.read<MakeProvider>().byId(id),
          ),
          IssuePage(:final id) => MakeSheet(edition: edition, magazineId: id),
          _ => MakeSheet(edition: edition),
        };
      case BurdaSheet.measure:
        return MeasureSheet(edition: edition);
      case BurdaSheet.lend:
        // Only ever raised from an issue, as the confirm sheet is.
        if (_top case IssuePage(:final id)) {
          final magazine = context.read<MagazineProvider>().byId(id);
          if (magazine != null) {
            return LendSheet(edition: edition, magazine: magazine);
          }
        }
        return null;
      case BurdaSheet.confirm:
        // Raised from whatever is on top, which is the thing being removed.
        switch (_top) {
          case IssuePage(:final id):
            final magazine = context.read<MagazineProvider>().byId(id);
            if (magazine != null) {
              return ConfirmSheet(edition: edition, magazine: magazine);
            }
          case MakePage(:final id):
            final make = context.read<MakeProvider>().byId(id);
            if (make != null) {
              return ConfirmMakeSheet(edition: edition, make: make);
            }
          default:
            return null;
        }
        return null;
    }
  }

  Widget _page(Edition edition) => switch (_top) {
    null => switch (_tab) {
      NavTab.home => IndexScreen(edition: edition),
      NavTab.collection => CollectionScreen(
        edition: edition,
        showOwned: _showOwned,
      ),
      NavTab.years => YearsScreen(edition: edition),
      NavTab.profile => ProfileScreen(edition: edition),
    },
    IssuePage(:final id) => IssueScreen(edition: edition, id: id),
    NotesPage() => NotesScreen(edition: edition),
    VaultPage() => VaultScreen(edition: edition),
    MakesPage() => MakesScreen(edition: edition),
    QueuePage() => QueueScreen(edition: edition),
    MeasurePage() => MeasureScreen(edition: edition),
    MakePage(:final id) => MakeScreen(edition: edition, id: id),
    YearPage(:final year, :final series) => YearScreen(
      edition: edition,
      year: year,
      series: series,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final edition = context.watch<ThemeProvider>().edition;
    final topInset = MediaQuery.paddingOf(context).top;

    return BurdaNavScope(
      nav: this,
      child: PopScope(
        canPop:
            _reader == null &&
            _sheet == null &&
            _stack.isEmpty &&
            _tab == NavTab.home,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          // The reader is on top of everything, so it closes first.
          if (_reader != null) return closeReader();
          if (_sheet != null) return closeSheet();
          if (_stack.isNotEmpty) return back();
          if (_tab != NavTab.home) goTab(NavTab.home);
        },
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: edition.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            color: edition.paper,
            // The design draws every surface itself, but the text fields in
            // the sheets still need a Material above them.
            child: Material(
              type: MaterialType.transparency,
              child: Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: PageStorage(
                          bucket: _bucket,
                          child: _PageEntrance(
                            pageKey: _pageKey,
                            // A pushed page comes in from the side, a tab fades up.
                            fromSide: _top != null,
                            child: SingleChildScrollView(
                              key: PageStorageKey(_pageKey),
                              padding: EdgeInsets.only(top: topInset + 10),
                              child: _page(edition),
                            ),
                          ),
                        ),
                      ),
                      NavBar(
                        edition: edition,
                        current: _top == null ? _tab : null,
                        onSelect: goTab,
                        onAdd: () => openSheet(BurdaSheet.add),
                      ),
                    ],
                  ),
                  if (_sheetContent(edition) case final sheet?)
                    Positioned.fill(
                      child: SheetScaffold(
                        edition: edition,
                        onClose: closeSheet,
                        child: sheet,
                      ),
                    ),
                  if (_reader case final reader?)
                    Positioned.fill(
                      child: ContentsReader(
                        // Reopening at another page builds a fresh controller,
                        // rather than animating across from where it was left.
                        key: ValueKey('${reader.magazineId}:${reader.startAt}'),
                        edition: edition,
                        magazineId: reader.magazineId,
                        startAt: reader.startAt,
                      ),
                    ),
                  if (_raining case final shower?)
                    Positioned.fill(
                      child: FallingHearts(
                        key: ValueKey(shower),
                        edition: edition,
                        onDone: () {
                          if (mounted && _raining == shower) {
                            setState(() => _raining = null);
                          }
                        },
                      ),
                    ),
                  if (_hearts)
                    Positioned.fill(
                      child: Hearts(
                        edition: edition,
                        onDone: () {
                          if (mounted) setState(() => _hearts = false);
                        },
                      ),
                    ),
                  if (_toast != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 124,
                      child: Center(
                        child: Toast(message: _toast!, edition: edition),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Replays the design's `pageIn` or `pageInX` whenever the page changes.
class _PageEntrance extends StatefulWidget {
  const _PageEntrance({
    required this.pageKey,
    required this.fromSide,
    required this.child,
  });

  final String pageKey;
  final bool fromSide;
  final Widget child;

  @override
  State<_PageEntrance> createState() => _PageEntranceState();
}

class _PageEntranceState extends State<_PageEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.fromSide ? AppMotion.pageInX : AppMotion.pageIn,
  )..forward();

  @override
  void didUpdateWidget(_PageEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pageKey == oldWidget.pageKey) return;
    _controller
      ..duration = widget.fromSide ? AppMotion.pageInX : AppMotion.pageIn
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.standard,
    );

    return FadeTransition(
      opacity: curved,
      child: AnimatedBuilder(
        animation: curved,
        builder: (context, child) {
          final remaining = 1 - curved.value;
          return Transform.translate(
            offset: widget.fromSide
                ? Offset(28 * remaining, 0)
                : Offset(0, 14 * remaining),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
