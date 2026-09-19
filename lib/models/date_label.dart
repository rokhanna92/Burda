/// Month names as the design prints them.
///
/// Spelled out here rather than taken from the device locale, because the app
/// is set in English throughout and a date reading "septembre" next to
/// "Édition Rosé" would be the only translated string on the screen.
const List<String> kMonths = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// `"September 2026"`, for the line under the logo.
String monthAndYear(DateTime date) => '${kMonths[date.month - 1]} ${date.year}';

/// `"2 September 2026"`, for a note's date.
String dayMonthYear(DateTime date) =>
    '${date.day} ${kMonths[date.month - 1]} ${date.year}';
