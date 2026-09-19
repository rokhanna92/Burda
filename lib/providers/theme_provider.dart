import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/edition.dart';

/// The édition the app is printed in, persisted.
///
/// The preference key matches the original app's: `theme`. The stored value
/// used to be one of the eight palette names, and none of those is an édition
/// id, so an install carrying one falls back to Rosé through [Edition.byId] and
/// is rewritten the first time a new édition is picked.
class ThemeProvider extends ChangeNotifier {
  static const String themeKey = 'theme';

  Edition _edition = Edition.rose;

  Edition get edition => _edition;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _edition = Edition.byId(prefs.getString(themeKey));
    notifyListeners();
  }

  Future<void> setEdition(Edition edition) async {
    if (edition.id == _edition.id) return;
    _edition = edition;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(themeKey, edition.id);
  }
}
