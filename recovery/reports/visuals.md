# Burda Style - Visual Design System, Animations and Widgets (recovery report)

Status: IN PROGRESS (written incrementally, do not treat as final until the "Report complete" marker at the bottom).

Evidence base: `/home/x3kk3x/Desktop/Burda/recovery/libapp_strings.txt` (28406 lines, arm64 `libapp.so`), asset files under `/home/x3kk3x/Desktop/Burda/assets/`.
All line numbers below refer to `libapp_strings.txt` unless stated otherwise.

Confidence tags: [CONFIRMED] direct evidence cited, [INFERRED] strong inference with reason, [GUESS] speculation.

## 0. Library-hash map (key to attributing names to Dart files)

Dart AOT private names carry a `@<libraryhash>` suffix. Mapping recovered from anchor symbols:

| hash | Dart file | anchor evidence |
|---|---|---|
| 472384369 | providers/theme_provider.dart | `_saveTheme@472384369` L2241, `_setPalette@472384369` L2271, `_loadTheme@472384369` L6213, `_saveQuotesState@472384369` L13345 |
| 471337958 | providers/magazine_provider.dart | `_MagazineProvider&Object&ChangeNotifier@471337958` L14385 |
| 475369058 | models/note_provider.dart | `_loadNotes@475369058` L7887 |
| 512325836 | widgets/title_text.dart | `_TitleTextState@512325836` L3587 |
| 511253204 | widgets/raining_hearts.dart | `_RainingHeartsState@511253204` L8236 |
| 513339066 | widgets/quote_display.dart | `_QuoteDisplayState@513339066` L10106 |
| 516108974 | widgets/collection_progress.dart | `_CollectionProgressState@516108974` L10474 |
| 517450674 | widgets/collection_stats.dart | `_CollectionStatsState@517450674` L10856 |
| 514513482 | widgets/floating_background.dart | `_FloatingBackgroundState@514513482` L12667 |
| 476342565 | screens/magazine_issue_detail_screen.dart | `_MagazineIssueDetailScreenState@476342565` L2381 |
| 470264457 | screens/notes_screen.dart | `_NotesScreenState@470264457` L6600 |
| 465443711 | screens/browse_magazines_screen.dart | `_BrowseMagazinesScreenState@465443711` L9253 |
| 466417668 | screens/owned_magazines_screen.dart | `_OwnedMagazinesScreenState@466417668` L12306 |
| 467438405 | screens/missing_magazines_screen.dart | `_MissingMagazinesScreenState@467438405` L10309 |
| 469241397 | screens/settings_screen.dart | `_exportMagazines@469241397` L10455, `_importMagazines@469241397` L13188, `_shareMagazines@469241397` L6240 |

(more to be filled in)

## 1. Theme system

Headline: this is NOT a plain light/dark toggle. It is a named colour-family palette picker with light / dark / deep variants per family.

- [CONFIRMED] Palette variant identifiers present as strings: `lightRed` L11635, `darkRed` L15430, `deepRed` L2256, `lightOrangeV` L8298, `darkOrange` L2384, `deepOrange` L8289, `lightGreen` L14408, `darkGreen` L2731, `deepGreen` L6017, `lightBlue` L9126, `darkBlue` L11684, `deepBlue` L11891, `lightPurple` L16139, `darkPurple` L15004, `deepPurple` L10980, `lightPink` L7496, `deepPink` L3421, `lightMaroon` L2767, `darkMaroon` L15362, `deepMaroon` L6488, `lightMellon` L3208, `darkMellon` L10831, `deepMellon` L4137, `lightBlack` L13987, `darkBlack` L10433.
- [CONFIRMED] Uppercase family keys: `BLUE` L5634, `PURPLE` L9902, `MAROON` L10466, `GREEN` L11551, `ORANGE` L12328, `MELLON` L12473, `PINK` L16352.
- [CONFIRMED] Debug strings: `Main.dart theme colors - deepColor: ` L4589, `, lightColor: ` L5957, `Dark color retrieved: ` L4659, `Loaded theme: ` L3196, `Theme changed to ` L5731, `Error retrieving colors: ` (L2247 area).
- [CONFIRMED] Field names `deepColor` L14043, `darkColor` L6073.
- [CONFIRMED] `useMaterial3` L4636 present.
- [CONFIRMED] theme_provider.dart also owns the quote toggle: `_saveQuotesState@472384369` L13345, `toggleQuotes` L10185, `Quotes enabled: ` L5366, `Enable Quotes` L6195.

(details to be filled in)

## 2. Typography

(to be filled in)

## 3. Motion inventory

(to be filled in)

## 4. Widgets

(to be filled in)

## 5. Asset catalogue

(to be filled in)
