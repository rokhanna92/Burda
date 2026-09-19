import 'package:flutter/widgets.dart';

import '../widgets/nav_bar.dart';

/// A page pushed over a tab.
///
/// These sit on a stack inside the shell rather than on Navigator's, because
/// the design keeps the nav bar in place while they slide in over it.
sealed class BurdaPage {
  const BurdaPage();
}

class YearPage extends BurdaPage {
  const YearPage(this.year);

  final int year;
}

class IssuePage extends BurdaPage {
  const IssuePage(this.id);

  /// The issue's `"<issue>-<year>"` id.
  final String id;
}

class NotesPage extends BurdaPage {
  const NotesPage();
}

class VaultPage extends BurdaPage {
  const VaultPage();
}

/// The six things the one bottom sheet can hold.
enum BurdaSheet { add, search, rank, about, note, confirm }

/// What a screen can ask the shell to do.
///
/// Screens reach this with `BurdaNav.of(context)` instead of taking a callback
/// for every destination, which keeps them free of plumbing and lets a test
/// hand them a stand-in.
abstract interface class BurdaNav {
  /// Switches tab, emptying the stack and closing any sheet.
  void goTab(NavTab tab);

  /// Opens the collection showing either what is held or what is still out
  /// there, which is how the index's first two lines get there.
  void showCollection({required bool owned});

  /// Pushes a page over the current tab.
  void push(BurdaPage page);

  /// Pops the top page.
  void back();

  void openSheet(BurdaSheet sheet);

  void closeSheet();

  /// Floats a line over the nav bar for a moment.
  void showToast(String message);

  /// Rains hearts and floats [message]. For a finished volume.
  void celebrate(String message);

  static BurdaNav of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<BurdaNavScope>();
    assert(scope != null, 'No BurdaShell above this screen');
    return scope!.nav;
  }
}

/// Carries the shell down to the screens.
///
/// Never notifies: the shell's identity does not change while it is mounted,
/// and screens call it rather than render it.
class BurdaNavScope extends InheritedWidget {
  const BurdaNavScope({super.key, required this.nav, required super.child});

  final BurdaNav nav;

  @override
  bool updateShouldNotify(BurdaNavScope oldWidget) => false;
}
