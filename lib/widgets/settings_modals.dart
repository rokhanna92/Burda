import 'package:flutter/material.dart';

/// The privacy note, kept word for word from the original. It is a joke.
Future<void> showPrivacyModal(BuildContext context) {
  final theme = Theme.of(context);
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        'Privacy & Security',
        textAlign: TextAlign.center,
        style: theme.textTheme.titleLarge,
      ),
      content: Text(
        'The data this app uses? It’s already in your storage. Now, I own '
        'everything you type, click, share, and see.\n\n'
        'Maybe I’m even watching you through your camera right now.\n\n'
        'I’m always here.',
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
      ),
      actions: [Center(child: _CloseButton())],
    ),
  );
}

/// The about text, kept word for word, with the real version number.
Future<void> showAboutModal(BuildContext context, {required String version}) {
  final theme = Theme.of(context);
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        'About Burda Style',
        textAlign: TextAlign.center,
        style: theme.textTheme.titleLarge,
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version: $version',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Welcome to Burda Style, a premier digital companion for fashion '
              'enthusiasts and collectors. This app serves as a precise '
              'timekeeping tool while preserving the rich heritage of '
              'Burda’s iconic designs\n\n'
              'Crafted with dedication, Burda Style is more than a utility - '
              'it is a trusted archive of patterns, a curator of collections, '
              'and a resource for creativity. Designed to endure, it ensures '
              'that every detail is securely stored, allowing users to track '
              'and manage their treasured designs with ease, no matter where '
              'their journey takes them\n\n'
              'For the discerning collector, knowledge is invaluable, and this '
              'app remains a steadfast tool. With every update, it continues '
              'to refine the user experience, keeping the legacy of Burda '
              'Style firmly in hand.',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ],
        ),
      ),
      actions: [Center(child: _CloseButton())],
    ),
  );
}

class _CloseButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: theme.colorScheme.onSurface,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 12),
      ),
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Close'),
    );
  }
}
