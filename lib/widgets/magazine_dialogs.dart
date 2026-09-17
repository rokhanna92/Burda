import 'package:flutter/material.dart';

import '../models/magazine.dart';

/// Rates an issue from 1 (Worn) to 10 (Mint). Returns the score, or null when
/// dismissed.
///
/// The original slider had no divisions and no value label, so you could not
/// tell what you were picking, and it reported "Condition set to 10.0".
/// This one snaps to whole numbers and shows them.
Future<int?> showConditionDialog(
  BuildContext context, {
  required Magazine magazine,
}) {
  final theme = Theme.of(context);
  var score = (magazine.conditionScore ?? 5).toDouble();

  return showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: theme.colorScheme.primary,
      title: Text(
        'Evaluate Condition for ${magazine.title}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 19),
      ),
      content: StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Rate the condition from 1 (Worn) to 10 (Mint)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: 10),
            Text(
              '${score.round()}  ${_labelFor(score.round())}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Slider(
              value: score,
              min: 1,
              max: 10,
              divisions: 9,
              label: '${score.round()}',
              onChanged: (value) => setState(() => score = value),
            ),
          ],
        ),
      ),
      actions: [
        Center(
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.secondary,
              foregroundColor: theme.colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 12),
            ),
            onPressed: () => Navigator.of(context).pop(score.round()),
            child: const Text(
              'SAVE',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    ),
  );
}

String _labelFor(int score) => switch (score) {
  >= 9 => '(Mint)',
  >= 5 => '(Good)',
  _ => '(Worn)',
};

/// Confirms removing an issue from the collection entirely.
Future<bool> showDeleteIssueDialog(BuildContext context) async {
  final theme = Theme.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(
        'Are you sure you want to delete this issue?',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyLarge,
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.onSurface,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
