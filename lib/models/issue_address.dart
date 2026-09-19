/// Reading an issue's address, "2/2024", from digits typed without the slash.
///
/// Hunting for `/` on a phone keypad is slower than typing the whole address,
/// so the slash is put in for you. Working out where it goes is not quite
/// trivial: "12" could be December, or issue 1 with a year starting to be
/// typed. Two facts settle it. An issue is 1 to 12, and every year in the
/// collection begins with a 2.
///
/// So after "1", "2" the next digit decides: a 0 means the year has started
/// (1 / 20xx), anything else means the issue was December (12 / 2xxx).
abstract final class IssueAddress {
  /// Longest issue number there is.
  static const int lastIssue = 12;

  /// How many of [digits] belong to the issue, or null while it is still
  /// impossible to say.
  static int? issueLength(String digits) {
    if (digits.isEmpty) return null;

    // 2 through 9 can only ever be the whole issue: there is no issue 20.
    if (digits[0] != '1') return 1;

    // A lone 1 could still become 10, 11 or 12.
    if (digits.length == 1) return null;

    // No year starts 10 or 11, so these are October and November.
    if (digits[1] == '0' || digits[1] == '1') return 2;

    if (digits[1] == '2') {
      // December, or issue 1 and the year has begun. The next digit says.
      if (digits.length == 2) return null;
      return digits[2] == '0' ? 1 : 2;
    }

    // 13 and up is not an issue, so the 1 stood alone.
    return 1;
  }

  /// Puts the slash into what has been typed.
  ///
  /// A slash typed by hand is honoured as it stands; this only steps in when
  /// there is none.
  static String format(String raw) {
    final cleaned = raw.replaceAll(RegExp('[^0-9/]'), '');

    if (cleaned.contains('/')) {
      // Keep the first slash and drop any others, so the field cannot end up
      // with "2//2024".
      final at = cleaned.indexOf('/');
      final issue = cleaned.substring(0, at);
      final year = cleaned.substring(at + 1).replaceAll('/', '');
      return '$issue/$year';
    }

    final length = issueLength(cleaned);
    if (length == null || cleaned.length <= length) return cleaned;
    return '${cleaned.substring(0, length)}/${cleaned.substring(length)}';
  }

  /// The issue and year an address points at, or null while it is incomplete.
  ///
  /// Nothing is looked up until the year is four digits long, so the result
  /// does not flicker between volumes as it is typed.
  static ({int issue, int year})? parse(String address) {
    final parts = address.split('/');
    if (parts.length != 2 || parts[1].length != 4) return null;

    final issue = int.tryParse(parts[0]);
    final year = int.tryParse(parts[1]);
    if (issue == null || year == null) return null;

    return (issue: issue, year: year);
  }
}
