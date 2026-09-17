import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/palette.dart';

/// Selected palette plus the home-screen quote toggle, both persisted.
///
/// Preference keys match the original app: `theme` and `quotesEnabled`.
class ThemeProvider extends ChangeNotifier {
  static const String themeKey = 'theme';
  static const String quotesKey = 'quotesEnabled';

  Palette _palette = Palette.pink;
  bool _quotesEnabled = true;

  Palette get palette => _palette;
  bool get quotesEnabled => _quotesEnabled;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _palette = Palette.byName(prefs.getString(themeKey));
    _quotesEnabled = prefs.getBool(quotesKey) ?? true;
    notifyListeners();
  }

  Future<void> setPalette(Palette palette) async {
    if (palette.name == _palette.name) return;
    _palette = palette;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(themeKey, palette.name);
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
