import 'package:flutter/material.dart';

import 'edition.dart';
import 'typography.dart';

/// Builds the app theme for the chosen [edition].
///
/// The redesign draws its own surfaces almost everywhere, so this stays thin:
/// it maps the édition's four roles onto the scheme Material needs and sets
/// the serif as the default face. Anything with a size or a tracking in the
/// design is built with [AppType] at the call site instead.
ThemeData buildAppTheme(Edition edition) {
  final colorScheme = ColorScheme(
    brightness: edition.dark ? Brightness.dark : Brightness.light,
    primary: edition.accent,
    // The design prints white on the accent wherever the two meet, in both
    // the day and the night éditions.
    onPrimary: Colors.white,
    secondary: edition.tint,
    onSecondary: edition.ink,
    surface: edition.paper,
    onSurface: edition.ink,
    error: edition.accent,
    onError: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: edition.paper,
    fontFamily: AppFonts.serif,
    textTheme: TextTheme(
      displayLarge: AppType.serif(size: 46, weight: 500, color: edition.ink),
      titleLarge: AppType.serif(size: 30, weight: 500, color: edition.ink),
      titleMedium: AppType.serif(size: 24, color: edition.ink),
      bodyLarge: AppType.serif(size: 19, color: edition.ink),
      bodyMedium: AppType.serif(size: 17, color: edition.ink),
      labelLarge: AppType.smallCaps(
        size: 15,
        trackingEm: 0.14,
        color: edition.ink,
      ),
    ),
    // Every sheet in the design paints its own panel and scrim.
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
  );
}
