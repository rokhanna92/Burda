import 'package:shared_preferences/shared_preferences.dart';

/// Counts the distinct days the app has been opened.
///
/// The original app kept this in `visit_days.json` in its documents directory;
/// preferences hold the same list with less ceremony.
abstract final class VisitService {
  static const String key = 'visitDays';

  /// Records today and returns how many distinct days have been seen.
  static Future<int> recordVisit({DateTime? today}) async {
    final prefs = await SharedPreferences.getInstance();
    final days = prefs.getStringList(key)?.toSet() ?? <String>{};
    days.add(_dayKey(today ?? DateTime.now()));
    final sorted = days.toList()..sort();
    await prefs.setStringList(key, sorted);
    return sorted.length;
  }

  static Future<int> daysVisited() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key)?.length ?? 0;
  }

  static String _dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
