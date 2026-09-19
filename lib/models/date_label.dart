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

/// Days after which a loan is printed in the accent.
///
/// Six months: two seasons of sewing, long enough that she has certainly
/// finished with it.
const int kLongLoan = 182;

/// Whole days between two moments, counted as a calendar would.
///
/// Both dates are flattened to midnight first, so a magazine lent last night is
/// a day gone this morning rather than a few hours. The hours are rounded
/// rather than truncated, because an hour lost to a clock change would
/// otherwise turn a day into none.
int wholeDays(DateTime from, DateTime to) {
  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day);
  return (end.difference(start).inHours / 24).round();
}

/// How long ago something was, in the words she would use for it.
///
/// Rounds hard on purpose. An issue that went out in March is five months gone
/// whether that is 148 days or 163, and a number nobody would say out loud is a
/// worse answer than a round one that is true. Nothing here scolds: the reading
/// gets longer, and that is the whole of the complaint.
String elapsed(DateTime from, DateTime now) {
  final days = wholeDays(from, now);
  return switch (days) {
    <= 0 => 'today',
    1 => 'yesterday',
    < 7 => '$days days',
    < 14 => 'a week',
    < 31 => '${(days / 7).round()} weeks',
    < 61 => 'a month',
    < 345 => '${(days / 30.44).round()} months',
    < 550 => 'a year',
    _ => '${(days / 365.25).round()} years',
  };
}
