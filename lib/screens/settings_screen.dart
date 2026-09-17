import 'package:flutter/material.dart';

/// Settings. Built in the next step.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Center(
        child: Text('Settings', style: theme.textTheme.displayLarge),
      ),
    );
  }
}
