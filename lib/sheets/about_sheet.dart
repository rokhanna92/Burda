import 'package:flutter/material.dart';

import '../theme/edition.dart';
import '../theme/typography.dart';
import '../widgets/sheet_scaffold.dart';

/// The about text, carried over from the original app word for word.
class AboutSheet extends StatelessWidget {
  const AboutSheet({super.key, required this.edition});

  final Edition edition;

  static const List<String> paragraphs = [
    'Welcome to Burda Style, a premier digital companion for fashion '
        'enthusiasts and collectors. This app serves as a precise timekeeping '
        'tool while preserving the rich heritage of Burda’s iconic designs',
    'Crafted with dedication, Burda Style is more than a utility - it is a '
        'trusted archive of patterns, a curator of collections, and a resource '
        'for creativity. Designed to endure, it ensures that every detail is '
        'securely stored, allowing users to track and manage their treasured '
        'designs with ease, no matter where their journey takes them',
    'For the discerning collector, knowledge is invaluable, and this app '
        'remains a steadfast tool. With every update, it continues to refine '
        'the user experience, keeping the legacy of Burda Style firmly in hand.',
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SheetHeading(
        edition: edition,
        eyebrow: 'Version 2.0',
        title: 'About Burda Style',
      ),
      for (final (index, paragraph) in paragraphs.indexed)
        Padding(
          padding: EdgeInsets.only(top: index == 0 ? 18 : 14),
          child: Text(
            paragraph,
            style: AppType.serif(size: 17, height: 1.45, color: edition.ink),
          ),
        ),
    ],
  );
}
