import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/magazine.dart';
import '../providers/magazine_provider.dart';
import 'search_modal.dart' show maxSearchYear, minSearchYear;

/// Highest year a whole year can be added at once. Beyond this the issue
/// numbering is not known yet, so issues go in one by one.
const int maxBulkYear = 2025;

/// Adds a single issue, or a whole year at once.
Future<void> showAddMagazineModal(BuildContext context) => showDialog(
  context: context,
  builder: (context) => const _AddMagazineDialog(),
);

class _AddMagazineDialog extends StatefulWidget {
  const _AddMagazineDialog();

  @override
  State<_AddMagazineDialog> createState() => _AddMagazineDialogState();
}

class _AddMagazineDialogState extends State<_AddMagazineDialog> {
  late final TextEditingController _year = TextEditingController(
    text: '${DateTime.now().year}',
  );
  int _issue = 1;

  @override
  void dispose() {
    _year.dispose();
    super.dispose();
  }

  void _fail(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _done(String message) {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// The entered year when it is usable, otherwise null after complaining.
  int? _validatedYear() {
    final year = int.tryParse(_year.text.trim());
    if (year == null) {
      _fail('Please select an issue and a valid year!');
      return null;
    }
    if (year < minSearchYear || year > maxSearchYear) {
      _fail(
        'Please select a valid issue and year '
        '($minSearchYear-$maxSearchYear)',
      );
      return null;
    }
    return year;
  }

  Magazine _buildIssue(int issue, int year) => Magazine(
    id: '$issue-$year',
    title: '$issue/$year',
    year: year,
    image: 'covers/$issue-$year.jpg',
  );

  Future<void> _addIssue() async {
    final provider = context.read<MagazineProvider>();
    final year = _validatedYear();
    if (year == null) return;
    if (provider.byId('$_issue-$year') != null) {
      _fail('This issue already exists!');
      return;
    }
    if (provider.magazinesForYear(year).length >= 12) {
      _fail('This year already has 12 issues!');
      return;
    }
    await provider.addMagazine(_buildIssue(_issue, year));
    if (mounted) _done('Added $_issue/$year to your collection!');
  }

  Future<void> _addYear() async {
    final provider = context.read<MagazineProvider>();
    final year = _validatedYear();
    if (year == null) return;
    if (year > maxBulkYear) {
      _fail('You must add issues one by one after $maxBulkYear!');
      return;
    }
    final existing = provider.magazinesForYear(year);
    if (existing.length >= 12) {
      _fail('This year already has 12 issues!');
      return;
    }
    final have = existing.map((m) => m.issue).toSet();
    for (var number = 1; number <= 12; number++) {
      if (have.contains(number)) continue;
      await provider.addMagazine(_buildIssue(number, year));
    }
    if (mounted) _done('Added $year to your collection!');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(
        'Add an issue',
        textAlign: TextAlign.center,
        style: theme.textTheme.titleLarge,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('Issue', style: theme.textTheme.bodyMedium),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<int>(
                  value: _issue,
                  isExpanded: true,
                  items: [
                    for (var number = 1; number <= 12; number++)
                      DropdownMenuItem(
                        value: number,
                        child: Text(
                          '$number',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _issue = value ?? _issue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _year,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Year'),
          ),
        ],
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _addYear,
              child: Text(
                'Add Year',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.onSurface,
                foregroundColor: Colors.white,
              ),
              onPressed: _addIssue,
              child: const Text('ADD'),
            ),
          ],
        ),
      ],
    );
  }
}
