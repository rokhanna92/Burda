import 'package:flutter/material.dart';

import 'edition.dart';

/// The kind of particle drifting in the nav bar's window.
enum Season { petals, sun, leaves, snow, dust, stars, embers }

/// The little weather scene behind the add button, one per édition.
///
/// A vertical [sky], a [ground] haze fading up from the bottom 30%, and the
/// [season] of particles drifting over both.
@immutable
class SeasonScene {
  const SeasonScene({
    required this.season,
    required this.sky,
    required this.ground,
  });

  final Season season;

  /// Top to bottom.
  final LinearGradient sky;

  /// Bottom to top, fading to nothing.
  final LinearGradient ground;

  /// The scene an édition is printed with.
  static SeasonScene of(Edition edition) => _scenes[edition.id]!;

  static LinearGradient _sky(List<Color> colors, [List<double>? stops]) =>
      LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
        stops: stops,
      );

  static LinearGradient _ground(List<Color> colors, [List<double>? stops]) =>
      LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: colors,
        stops: stops,
      );

  static const Color _clear = Color(0x00000000);

  static final Map<String, SeasonScene> _scenes = {
    'rose': SeasonScene(
      season: Season.petals,
      sky: _sky(const [Color(0xFFFBE3EA), Color(0xFFF3C4D1)]),
      ground: _ground(const [Color(0x59C2445F), _clear]),
    ),
    'printemps': SeasonScene(
      season: Season.petals,
      sky: _sky(const [Color(0xFFE7F0FA), Color(0xFFD6E9D3)]),
      ground: _ground(const [Color(0x803F7A4C), _clear]),
    ),
    'ete': SeasonScene(
      season: Season.sun,
      sky: _sky(
        const [Color(0xFFFFD98A), Color(0xFFF2B15E), Color(0xFFD97A3A)],
        const [0, 0.6, 1],
      ),
      ground: _ground(const [Color(0x73783C14), _clear]),
    ),
    'automne': SeasonScene(
      season: Season.leaves,
      sky: _sky(const [Color(0xFFE9D2B0), Color(0xFFD6A876)]),
      ground: _ground(const [Color(0x8C5A2D14), _clear]),
    ),
    'hiver': SeasonScene(
      season: Season.snow,
      sky: _sky(
        const [Color(0xFF3E5A85), Color(0xFF6F89B5), Color(0xFFD9E3F0)],
        const [0, 0.7, 1],
      ),
      ground: _ground(
        const [Color(0xE6FFFFFF), Color(0x66FFFFFF), _clear],
        const [0, 0.6, 1],
      ),
    ),
    'maroon': SeasonScene(
      season: Season.dust,
      sky: _sky(const [Color(0xFF4A1620), Color(0xFF7A2A36)]),
      ground: _ground(const [Color(0x59000000), _clear]),
    ),
    'lavande': SeasonScene(
      season: Season.petals,
      sky: _sky(const [Color(0xFFE9E1F3), Color(0xFFC9B8E4)]),
      ground: _ground(const [Color(0x736B4E9B), _clear]),
    ),
    'nuit': SeasonScene(
      season: Season.stars,
      sky: _sky(const [Color(0xFF0B1020), Color(0xFF1C2A4A)]),
      ground: _ground(const [Color(0x80000000), _clear]),
    ),
    'noir': SeasonScene(
      season: Season.stars,
      sky: _sky(const [Color(0xFF0A0908), Color(0xFF1E1A14)]),
      ground: _ground(const [Color(0x40C9A45C), _clear]),
    ),
    'bordeaux': SeasonScene(
      season: Season.embers,
      sky: _sky(const [Color(0xFF1A0A0E), Color(0xFF3A1119)]),
      ground: _ground(const [Color(0x73D9556F), _clear]),
    ),

    // The clear set.
    'fuchsia': SeasonScene(
      season: Season.petals,
      sky: _sky(const [Color(0xFFFFE7F2), Color(0xFFFFC2DE)]),
      ground: _ground(const [Color(0x66B8005A), _clear]),
    ),
    'rubis': SeasonScene(
      season: Season.petals,
      sky: _sky(const [Color(0xFFFFE9E6), Color(0xFFFFC4BD)]),
      ground: _ground(const [Color(0x66A80018), _clear]),
    ),
    'cobalt': SeasonScene(
      season: Season.snow,
      sky: _sky(
        const [Color(0xFFDCEBFF), Color(0xFFA9C8F5), Color(0xFF7FA9E8)],
        const [0, 0.6, 1],
      ),
      ground: _ground(const [Color(0x66003C8F), _clear]),
    ),
    'emeraude': SeasonScene(
      season: Season.petals,
      sky: _sky(const [Color(0xFFE4F7EA), Color(0xFFBFE6CD)]),
      ground: _ground(const [Color(0x66005C36), _clear]),
    ),
    'orchidee': SeasonScene(
      season: Season.petals,
      sky: _sky(const [Color(0xFF1A0A16), Color(0xFF3A1830)]),
      ground: _ground(const [Color(0x73FF8FC2), _clear]),
    ),
    'carmin': SeasonScene(
      season: Season.embers,
      sky: _sky(const [Color(0xFF1A0709), Color(0xFF3A1016)]),
      ground: _ground(const [Color(0x73FF7B84), _clear]),
    ),
    'indigo': SeasonScene(
      season: Season.stars,
      sky: _sky(const [Color(0xFF060B1A), Color(0xFF131F3E)]),
      ground: _ground(const [Color(0x669DBEFF), _clear]),
    ),
    'sapin': SeasonScene(
      season: Season.dust,
      sky: _sky(const [Color(0xFF04140C), Color(0xFF0D2E1B)]),
      ground: _ground(const [Color(0x736FE9AC), _clear]),
    ),
  };
}
