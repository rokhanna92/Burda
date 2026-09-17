import 'package:flutter/material.dart';

/// One selectable colour family.
///
/// Every palette carries the same three roles the original app exposed:
/// [deep] for the app bar and bottom navigation, [dark] for text, and [light]
/// for cards, tiles and the progress track. Values are sampled from the
/// original app running on a device.
class Palette {
  const Palette({
    required this.name,
    required this.label,
    required this.deep,
    required this.dark,
    required this.light,
  });

  /// Stored in preferences under `theme`.
  final String name;

  /// Swatch caption in settings, e.g. `PINK`.
  final String label;

  final Color deep;
  final Color dark;
  final Color light;

  /// Settings lists these in two columns, in this order.
  static const List<Palette> all = [
    pink,
    green,
    purple,
    blue,
    red,
    orange,
    mellon,
    maroon,
  ];

  static const Palette pink = Palette(
    name: 'pink',
    label: 'PINK',
    deep: Color(0xFFE91E63),
    dark: Color(0xFFB71C1C),
    light: Color(0xFFF8BBD0),
  );

  static const Palette green = Palette(
    name: 'green',
    label: 'GREEN',
    deep: Color(0xFF18230F),
    dark: Color(0xFF27391C),
    light: Color(0xFF8BC34A),
  );

  static const Palette purple = Palette(
    name: 'purple',
    label: 'PURPLE',
    deep: Color(0xFF17153B),
    dark: Color(0xFF2E236C),
    light: Color(0xFFE1BEE7),
  );

  static const Palette blue = Palette(
    name: 'blue',
    label: 'BLUE',
    deep: Color(0xFF0B2447),
    dark: Color(0xFF19376D),
    light: Color(0xFF90CAF9),
  );

  static const Palette red = Palette(
    name: 'red',
    label: 'RED',
    deep: Color(0xFF740938),
    dark: Color(0xFFAF1740),
    light: Color(0xFFEF9A9A),
  );

  static const Palette orange = Palette(
    name: 'orange',
    label: 'ORANGE',
    deep: Color(0xFFEB5A3C),
    dark: Color(0xFFDF9755),
    light: Color(0xFFF5CBA7),
  );

  static const Palette mellon = Palette(
    name: 'mellon',
    label: 'MELLON',
    deep: Color(0xFF5D8736),
    dark: Color(0xFF809D3C),
    light: Color(0xFFDCE775),
  );

  static const Palette maroon = Palette(
    name: 'maroon',
    label: 'MAROON',
    deep: Color(0xFF0C0C0C),
    dark: Color(0xFF481E14),
    light: Color(0xFFEF5350),
  );

  static Palette byName(String? name) => all.firstWhere(
    (palette) => palette.name == name,
    orElse: () => pink,
  );
}
