import 'package:burda/models/issue_address.dart';
import 'package:flutter_test/flutter_test.dart';

/// Types [keys] one at a time, the way a thumb does, and gives back what the
/// field reads after each press.
List<String> _typed(String keys) {
  final seen = <String>[];
  var field = '';
  for (final key in keys.split('')) {
    field = IssueAddress.format('$field$key');
    seen.add(field);
  }
  return seen;
}

void main() {
  group('where the issue ends', () {
    test('2 through 9 stand alone: there is no issue 20', () {
      for (final digit in ['2', '3', '4', '5', '6', '7', '8', '9']) {
        expect(IssueAddress.issueLength(digit), 1, reason: digit);
      }
    });

    test('a lone 1 is not decided yet: it could still be 10, 11 or 12', () {
      expect(IssueAddress.issueLength('1'), isNull);
    });

    test('10 and 11 are October and November: no year starts that way', () {
      expect(IssueAddress.issueLength('10'), 2);
      expect(IssueAddress.issueLength('11'), 2);
    });

    test('12 waits, because it could be December or issue 1 of a 2xxx', () {
      expect(IssueAddress.issueLength('12'), isNull);
    });

    test('a 0 after 12 means the year has begun, so the issue was 1', () {
      expect(IssueAddress.issueLength('120'), 1);
      expect(IssueAddress.issueLength('12024'), 1);
    });

    test('anything else after 12 means December', () {
      expect(IssueAddress.issueLength('122'), 2);
      expect(IssueAddress.issueLength('122024'), 2);
    });

    test('13 and up is not an issue, so the 1 stood alone', () {
      expect(IssueAddress.issueLength('13'), 1);
      expect(IssueAddress.issueLength('19'), 1);
    });

    test('nothing typed, nothing to say', () {
      expect(IssueAddress.issueLength(''), isNull);
    });
  });

  group('typing an address without the slash', () {
    test('a single-digit issue: 2 2 0 2 4', () {
      expect(_typed('22024'), ['2', '2/2', '2/20', '2/202', '2/2024']);
    });

    test('December: 1 2 2 0 2 4', () {
      expect(_typed('122024'), [
        '1',
        '12',
        '12/2',
        '12/20',
        '12/202',
        '12/2024',
      ]);
    });

    test('issue 1: 1 2 0 2 4', () {
      expect(_typed('12024'), ['1', '12', '1/20', '1/202', '1/2024']);
    });

    test('October: 1 0 2 0 2 4', () {
      expect(_typed('102024').last, '10/2024');
    });

    test('November: 1 1 2 0 2 4', () {
      expect(_typed('112024').last, '11/2024');
    });

    test('every issue of a year lands where it should', () {
      for (var issue = 1; issue <= IssueAddress.lastIssue; issue++) {
        expect(
          _typed('${issue}2024').last,
          '$issue/2024',
          reason: 'issue $issue',
        );
      }
    });
  });

  group('format', () {
    test('keeps a slash that was typed by hand', () {
      expect(IssueAddress.format('7/2019'), '7/2019');
      expect(IssueAddress.format('7/'), '7/');
    });

    test('never lets a second slash through', () {
      expect(IssueAddress.format('7//2019'), '7/2019');
      expect(IssueAddress.format('7/20/19'), '7/2019');
    });

    test('throws away anything that is not a digit or a slash', () {
      expect(IssueAddress.format('7a/2019b'), '7/2019');
      expect(IssueAddress.format('  2 2024 '), '2/2024');
    });

    test('backspacing walks the slash back out again', () {
      expect(IssueAddress.format('2/2024'), '2/2024');
      expect(IssueAddress.format('2/202'), '2/202');
      expect(IssueAddress.format('2/'), '2/');
      expect(IssueAddress.format('2'), '2');
      expect(IssueAddress.format(''), '');
    });
  });

  group('parse', () {
    test('reads a whole address', () {
      expect(IssueAddress.parse('2/2024'), (issue: 2, year: 2024));
      expect(IssueAddress.parse('12/2010'), (issue: 12, year: 2010));
    });

    test('waits for all four digits of the year', () {
      expect(IssueAddress.parse('2/202'), isNull);
      expect(IssueAddress.parse('2/20245'), isNull);
      expect(IssueAddress.parse('2/'), isNull);
      expect(IssueAddress.parse('2'), isNull);
      expect(IssueAddress.parse(''), isNull);
    });
  });
}
