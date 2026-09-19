import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/edition.dart';

/// Selected édition plus the home-screen quote toggle, both persisted.
///
/// Preference keys match the original app: `theme` and `quotesEnabled`.
///
/// The stored value used to be one of the eight palette names. None of those
/// is an édition id, so an install carrying one falls back to Rosé through
/// [Edition.byId] and is rewritten the first time a new édition is picked.
class ThemeProvider extends ChangeNotifier {
  static const String themeKey = 'theme';
  static const String quotesKey = 'quotesEnabled';

  Edition _edition = Edition.rose;
  bool _quotesEnabled = true;

  Edition get edition => _edition;
  bool get quotesEnabled => _quotesEnabled;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _edition = Edition.byId(prefs.getString(themeKey));
    _quotesEnabled = prefs.getBool(quotesKey) ?? true;
    notifyListeners();
  }

  Future<void> setEdition(Edition edition) async {
    if (edition.id == _edition.id) return;
    _edition = edition;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(themeKey, edition.id);
  }

  Future<void> toggleQuotes() => setQuotesEnabled(!_quotesEnabled);

  Future<void> setQuotesEnabled(bool enabled) async {
    if (enabled == _quotesEnabled) return;
    _quotesEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(quotesKey, enabled);
  }
}
