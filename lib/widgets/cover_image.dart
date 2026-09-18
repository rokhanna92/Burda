import 'dart:io';

import 'package:flutter/material.dart';

import '../models/magazine.dart';

/// An issue's cover, from the bundled artwork or from a file the user picked.
///
/// Issues added by hand have no bundled cover, and the original app fell back
/// to an asset it never shipped, so the tile broke. This falls back to the
/// issue number on a plain card instead.
class CoverImage extends StatelessWidget {
  const CoverImage({super.key, required this.magazine, this.fit = BoxFit.cover});

  final Magazine magazine;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    Widget fallback(BuildContext context, Object error, StackTrace? stack) =>
        _MissingCover(title: magazine.title);

    if (magazine.hasFileCover) {
      return Image.file(
        File(magazine.image),
        fit: fit,
        errorBuilder: fallback,
      );
    }
    return Image.asset(
      'assets/${magazine.image}',
      fit: fit,
      errorBuilder: fallback,
    );
  }
}

class _MissingCover extends StatelessWidget {
  const _MissingCover({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.secondary,
      child: Center(
        child: Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(fontSize: 22),
        ),
      ),
    );
  }
}
