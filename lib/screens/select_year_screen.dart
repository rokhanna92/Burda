import 'package:flutter/material.dart';

/// Year browser. Built in the next step.
class SelectYearScreen extends StatelessWidget {
  const SelectYearScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Center(
        child: Text('Select Year', style: theme.textTheme.displayLarge),
      ),
    );
  }
}
