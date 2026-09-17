import 'package:flutter/material.dart';

import 'palette.dart';

/// Font families bundled with the app, named so call sites read clearly.
abstract final class AppFonts {
  /// The script face used for the "Burda Style" logo.
  static const String script = 'FleurDeLeah';

  /// The heavy slab face used for screen titles and section headings.
  static const String display = 'AlfaSlabOne';

  /// Body text.
  static const String body = 'Roboto';
}

/// Builds the app theme for a chosen [palette].
ThemeData buildAppTheme(Palette palette) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: palette.deep,
    primary: palette.deep,
    onPrimary: Colors.white,
    secondary: palette.light,
    onSecondary: palette.dark,
    surface: Colors.white,
    onSurface: palette.dark,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    fontFamily: AppFonts.body,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: AppBarTheme(
      backgroundColor: palette.deep,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
      titleTextStyle: const TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      color: palette.light,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    textTheme: TextTheme(
      // Screen titles: "Settings", "Browse Issues".
      displayLarge: TextStyle(
        fontFamily: AppFonts.display,
        fontSize: 44,
        color: palette.dark,
      ),
      // Section headings in settings.
      titleLarge: TextStyle(
        fontFamily: AppFonts.display,
        fontSize: 22,
        color: palette.deep,
      ),
      titleMedium: TextStyle(fontSize: 17, color: palette.dark),
      bodyLarge: TextStyle(fontSize: 17, color: palette.dark),
      bodyMedium: TextStyle(fontSize: 16, color: palette.dark),
      labelLarge: TextStyle(
        fontSize: 14,
        letterSpacing: 0.5,
        color: palette.dark,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: palette.deep,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 15),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: palette.light,
      inactiveTrackColor: Colors.white24,
      thumbColor: palette.light,
      valueIndicatorColor: palette.deep,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: palette.light,
      linearTrackColor: palette.light.withValues(alpha: 0.35),
    ),
  );
}
