import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/magazine_provider.dart';
import '../screens/magazine_issue_detail_screen.dart';

/// Lowest year the app accepts for a hand entered issue.
const int minSearchYear = 2000;

/// Highest year, one ahead of today so a new issue can be added early.
int get maxSearchYear => DateTime.now().year + 1;

/// Finds an issue by number and year, entered as `2/2024`.
Future<void> showSearchModal(BuildContext context) =>
    showDialog(context: context, builder: (context) => const _SearchDialog());

class _SearchDialog extends StatefulWidget {
  const _SearchDialog();

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _fail(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _submit() {
    final parts = _controller.text.trim().split('/');
    final issue = parts.isEmpty ? null : int.tryParse(parts.first.trim());
    final year = parts.length < 2 ? null : int.tryParse(parts[1].trim());

    if (issue == null || year == null) {
      _fail('Please select an issue and a valid year!');
      return;
    }
    if (issue < 1 ||
        issue > 12 ||
        year < minSearchYear ||
        year > maxSearchYear) {
      _fail(
        'Please select a valid issue and year '
        '($minSearchYear-$maxSearchYear)',
      );
      return;
    }

    final magazine = context.read<MagazineProvider>().byId('$issue-$year');
    if (magazine == null) {
      _fail('Magazine not found!');
      return;
    }

    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute(
        builder: (context) =>
            MagazineIssueDetailScreen(magazineId: magazine.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(
        'SEARCH',
        textAlign: TextAlign.center,
        style: theme.textTheme.titleLarge,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Enter an issue number and a year, like 2/2024',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
            ],
            textAlign: TextAlign.center,
            decoration: const InputDecoration(hintText: '2/2024'),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        Center(
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.onSurface,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            ),
            onPressed: _submit,
            child: const Text('SEARCH'),
          ),
        ),
      ],
    );
  }
}
