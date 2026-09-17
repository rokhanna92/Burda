# Burda Style APK recovery - user-facing strings (copy) report

Slice: every string a user of this app could see.
Primary evidence: `/home/x3kk3x/Desktop/Burda/recovery/libapp_strings.txt` (28406 lines, `strings` over
`apk/lib/arm64-v8a/libapp.so`) plus a byte-level re-extraction of the Dart snapshot string table done for
this report (see Method). Citations are `L<n>` for a libapp_strings.txt line number and `@<n>` for a byte
offset inside `apk/lib/arm64-v8a/libapp.so`.

---

## 0. Method and coverage (read this before trusting a line number)

1. Full sweep of libapp_strings.txt in chunks, filtered four ways so nothing was skipped: lines with an
   internal space (2436 lines, all read), lines with a leading/trailing space or ending in `:` or
   containing `!`/`?`, pure-alphabetic tokens, and tokens containing digits. Everything above line ~16613
   is machine code noise [CONFIRMED: last real Dart string is `get:toolbarTextStyle` L16613].
2. **libapp_strings.txt is incomplete in two ways, and this matters.** `strings` used its default 4-byte
   minimum, so every 1 to 3 character Dart string is missing from it, and `strings` is ASCII-only, so every
   Dart *two-byte* (UTF-16) string is missing entirely. Several of the most important pieces of app copy
   are two-byte strings and appear **nowhere** in libapp_strings.txt (section 4.9, 4.10, 4.11).
3. To close those gaps I decoded the snapshot's string table directly. Format [CONFIRMED by decoding]: a
   varint (7 bits per byte, little endian, terminating byte has bit 0x80 set) holding `length << 1`,
   followed by the bytes. Walking that chain yields 15788 exact strings with exact boundaries (no glued
   neighbours, trailing spaces preserved). A separate UTF-16LE scan recovered the two-byte strings.
4. Residual risk: 5 short regions of the chain desynchronised around two-byte strings. Every 4+ character
   string inside them is still present in libapp_strings.txt (reviewed), and I enumerated their 1 to 3
   character strings by hand: all were file extensions and MIME codes, no UI copy. [CONFIRMED]
5. No obfuscation. Library URIs, class names, method names and private-name library hashes are all intact.
6. Original source tree was `E:/UN Projects/Burda/burda/` on Windows [CONFIRMED L3866].

### Language

**English only.** [CONFIRMED] There is no second locale, no `intl` ARB/message catalogue, no
`AppLocalizations`, and no non-English app literal anywhere in the snapshot. The only non-ASCII characters
in app copy are the typographic apostrophe U+2019 (in "Burda's", "app's", "It's", "I'm"), U+2022 bullet
(tour lists), U+2122 trademark ("Soon™"), and one emoji U+1F6A7 🚧. Weekday/month/era names
("Anno Domini", "Before Christ", "3rd quarter", month names) come from `package:intl` en data, not from the
app. Copy voice is casual first-person-ish, sometimes jokey (see 4.10, 4.11).

---

## 1. Attribution key: library hash to Dart file [CONFIRMED]

Private Dart names carry an `@<libraryhash>` suffix. Decoding those suffixes gives a reliable file map,
which is what I used to attribute behaviour (and therefore likely copy placement) below. String *literals*
carry no such suffix and are stored in hash order, so literal-to-file attribution is inference, not proof.

| Hash | Dart file | Private members seen (evidence for what that file does) |
|---|---|---|
| 463142880 | main.dart | `_AppWrapperState` |
| 464176168 | screens/home_screen.dart | `_HomeScreenState`, `_showSearchModal`, `_showAddMagazineModal`, `_showRankModal`, `_buildRankRow`, `_countTotalImages`, `_loadVisitDays`, `_recordVisit`, `_saveImage`, `_loadMagazinesFuture`, `_searchButtonController`, `_verticalMovementController`, `_horizontalAnimationController` |
| 465443711 | screens/browse_magazines_screen.dart | `_BrowseMagazinesScreenState`, `_checkAndTriggerConfetti`, `_confettiController`, `_loadViewPreference`, `_saveViewPreference`, `_showAddMagazineModal`, `_showConditionModal` |
| 466417668 | screens/owned_magazines_screen.dart | `_OwnedMagazinesScreenState` |
| 467438405 | screens/missing_magazines_screen.dart | `_MissingMagazinesScreenState` |
| 468186903 | screens/select_year_screen.dart | `_SelectYearScreenState`, `_scrollController`, `_showAddMagazineModal` |
| 469241397 | screens/settings_screen.dart | `_SettingsScreenState`, `_buildSection`, `_buildThemeOption`, `_exportMagazines`, `_importMagazines`, `_shareMagazines`, `_showAboutModal`, `_showPrivacyModal`, `_showAddMagazineModal`, plus 5 per-section animation controllers (`_themeAnimationController`, `_quotesAnimationController`, `_privacyAnimationController`, `_dataAnimationController`, `_aboutAnimationController`) |
| 470264457 | screens/notes_screen.dart | `_NotesScreenState`, `_showAddNoteModal`, `_showNoteDetailsDialog`, `_showAddMagazineModal` |
| 471337958 | providers/magazine_provider.dart (mixin) | `_MagazineProvider&Object&ChangeNotifier` |
| 472384369 | providers/theme_provider.dart | `_loadTheme`, `_saveTheme`, `_setPalette`, `_saveQuotesState` |
| 475369058 | models/note_provider.dart | `_initDatabase`, `_loadNotes` |
| 476342565 | screens/magazine_issue_detail_screen.dart | `_MagazineIssueDetailScreenState`, `_loadImages`, `_pickAndSaveImage`, `_deleteImage`, `_showFullScreenImage` |
| 477102079 | screens/gallery_screen.dart | `_GalleryScreenState`, `_loadAllImages`, `_deleteImage`, `_showFullScreenImage` |
| 499116846 | services/database_service.dart or magazine_provider | `_initDatabase`, `_loadInitialData` |
| 501378081 | widgets/magazine_card.dart [INFERRED] | `_showDeleteModal` |
| 511253204 | widgets/raining_hearts.dart | `_RainingHeartsState`, `_xPositions`, `_yPositions`, `_speeds`, `_swayOffsets`, `_colors` |
| 512325836 | widgets/title_text.dart | `_TitleTextState` with `_controller1..6` and `_orbitAnimation1..6` (6 orbiting elements) |
| 513339066 | widgets/quote_display.dart | `_QuoteDisplayState`, `_GlitchTextState`, `_loadQuotes`, `_rotateQuote`, `_startQuoteRotation`, `_buildGlitchLayer`, `_glitchOffsets` |
| 514513482 | widgets/floating_background.dart | `_FloatingBackgroundState`, `_onCoffeeTap`, `_onModalCoffeeTap`, `_onTourTap`, `_onMapTap`, `_closeCoffeeModal`, `_closeTourModal`, `_closeMapModal`, `_loadCoffeeData`, `_saveCoffeeClick`, `_floatControllers` |
| 516108974 | widgets/collection_progress.dart | `_CollectionProgressState` |
| 517450674 | widgets/collection_stats.dart | `_CollectionStatsState`, `_buildStatRow`, `_buildImage`, `_getCollectorRankDetails` |

`widgets/info_blocks.dart`, `widgets/bottom_navigation.dart` and `providers/bottom_navigation_provider.dart`
have no private members in the snapshot, so they are almost certainly small stateless widgets / a trivial
`ChangeNotifier` [INFERRED].

Named routes [CONFIRMED]: `/home` L8680, `/browseMagazines` L6088, `/selectYear` L4685,
`/magazineIssueDetail` L9855, `/ownedMagazines` L14236, `/missingMagazines` L3423, `/gallery` L16510,
`/notes` L2130, `/settings` L15974, plus `/year/` L16461 (a prefix, so probably `'/year/' + year`).

---

## 2. The uppercase label set [CONFIRMED present, placement varies]

A distinct family of ALL-CAPS literals exists. None of them has a `get:`/`set:`/`init:` twin, which is what
a field name would have, so they are string literals, not identifiers. (Contrast `SIZE` L8814/@291859 and
`ENCRYPTED_SIZE` L6899, which *do* have `get:SIZE` L3122 and `init:ENCRYPTED_SIZE` L13085 twins and are
therefore plugin field names, **not** UI copy.)

| Text | Evidence | Most likely placement | Confidence |
|---|---|---|---|
| `OWNED` | L5222 @200225 | info block / owned screen label | [INFERRED] |
| `MISSING` | L8026 @269166 | info block / missing screen label | [INFERRED] |
| `VAULT` | L14473 @452285 | info block / gallery label (matches "No images in the vault yet.") | [INFERRED] |
| `NOTES` | L15321 @474032 | info block / notes label | [INFERRED] |
| `SEARCH` | L8522 @283507 | home search button (matches `_showSearchModal`) | [INFERRED] |
| `ADD` | absent from libapp_strings.txt (3 chars); @393499 | add-magazine modal confirm button | [INFERRED] |
| `SAVE` | L10866 @363575 | save button in a modal (note / image) | [INFERRED] |
| `RANK` | L11575 @382110 | home button opening the rank modal (`_showRankModal`) | [INFERRED] |
| `SHOW` | L14278 @447327 | a reveal/expand button | [GUESS] |
| `EXPORT` | L16178 @494861 | Data Management button (`_exportMagazines`) | [INFERRED] |
| `IMPORT` | L3504 @158031 | Data Management button (`_importMagazines`) | [INFERRED] |
| `WEAR` | L3315 @153559 | condition/wear label, probably on the issue card or condition modal | [GUESS] |
| `FILL` | L8814 @290719 | unclear; possibly an image-fit or progress-fill label | [GUESS] |

Theme swatch labels, also ALL-CAPS [CONFIRMED present]: `RED` (@375903, 3 chars so absent from the strings
file), `PINK` L16352, `ORANGE` L12328, `GREEN` L11551, `BLUE` L5634, `PURPLE` L9902, `MAROON` L10466,
`MELLON` L12473 (sic, "Mellon" not "Melon"). Placement: the Settings theme section built by
`_buildThemeOption` [INFERRED]. The underlying palette keys are `deep*`/`dark*`/`light*` triples for Red,
Pink, Orange, Green, Blue, Purple, Maroon, Mellon **and Black** (`deepBlack` L4589 region @168455,
`darkBlack` L10433, `lightBlack` L13987). There is no `BLACK` caps literal, so either the black theme has no
caps label or it is presented differently [open question for the runtime agent].

---

## 3. Mixed-case labels and titles [CONFIRMED present]

| Text | Evidence | Placement | Confidence |
|---|---|---|---|
| `Burda Style` | L7403 @254456 | app name / app bar title | [INFERRED] |
| `Burda Style Collection` | L6761 @237923 | home heading, likely the `TitleText` widget | [INFERRED] |
| `Home` | L9569 @307898 | bottom navigation item 1 (confirmed by the tour text, 4.9) | [CONFIRMED as nav label] |
| `Browse Issues` | L8919 @293302 | browse_magazines_screen title | [INFERRED] |
| `Add Year` | L10743 @360665 | select_year_screen action | [INFERRED] |
| `Add Note` | L7372 @253699 | notes_screen action / add-note modal title | [INFERRED] |
| `Upload Image` | L15846 @486752 | magazine_issue_detail action | [INFERRED] |
| `Evaluate Condition for ` | L11108 @368903 | condition modal title, concatenated with the issue title | [CONFIRMED template] |
| `Rate the condition from 1 (Worn) to 10 (Mint)` | L6284 @226166 | condition modal body | [INFERRED] |
| `Enable Quotes` | L6195 @223816 | Settings toggle label | [INFERRED] |
| `Theme` | L6210 @224223 | Settings section header | [INFERRED] |
| `Privacy & Security` | L10691 @359359 | Settings section header | [INFERRED] |
| `Data Management` | L15549 @479389 | Settings section header | [INFERRED] |
| `About Burda Style` | L9880 @326806 | Settings section header, and the first line of the About modal body | [CONFIRMED both] |
| `Burda Style Tour` | L13366 @426005 | tour modal title | [INFERRED] |
| `Coming Soon` | L11388 @375523 | the "Phone" floating icon (confirmed by the tour bullet, 4.9) | [CONFIRMED] |
| `Version: 1.8.1` | L3117 @148803 | version line (also inside the About body) | [CONFIRMED] |
| `Rank Levels:` | L14941 @463905 | rank modal header | [INFERRED] |
| `Bottom Navbar:` | L14297 @447749 | tour modal section header | [INFERRED] |
| `Floating Icons:` | L15599 @480666 | tour modal section header | [INFERRED] |
| `Click of the day` | L11303 @373450 | coffee-click counter label | [GUESS] |
| `Year: ` | L4764 @188602 | label prefix, issue detail or search modal | [INFERRED] |
| `Note` | L6917 @242054 | note field/label | [GUESS, could be a class-name string] |
| `Title` | L5371 @204210 | add-note title field label/hint | [GUESS] |
| `Content` | L4846 @190354 | add-note content field label/hint | [GUESS] |
| `Save` | L10744 @360674 | button (distinct from the caps `SAVE`) | [GUESS] |
| `Clear` | L13599 @431424 | button | [GUESS] |
| `About` | L16571 @504849 | label | [GUESS] |
| `Quote` | L13112 @419709 | label or class-name string | [GUESS] |
| `Image` | L16493 @502934 | label or class-name string | [GUESS] |

`Note`, `Title`, `Content`, `Quote`, `Image`, `Save`, `Clear`, `About`, `Select`, `Update`, `Row`, `New`,
`Set` all also plausibly exist as `Type.toString()` artefacts. I have flagged them [GUESS] rather than
claim them as copy.

---

## 4. Copy grouped by screen and widget

### 4.1 Home screen (`home_screen.dart`, @464176168)

| Text (exact) | Evidence | Confidence |
|---|---|---|
| `Welcome to Burda Style!\nTrack your magazine collection with ease.` (one literal, embedded newline) | L13809 + L13810, @436225 | [CONFIRMED text] [INFERRED placement] |
| `Burda Style Collection` | L6761 | [INFERRED] |
| `SEARCH`, `ADD`, `RANK` | section 2 | [INFERRED] |
| `Rank Levels:` | L14941 | [INFERRED] |
| `Days Visited: ` (trailing space, concatenated with a count) | L3220 @151334 | [CONFIRMED template] |
| `Click of the day` | L11303 | [GUESS] |

The home screen also hosts the quote rotator, the collection stats/progress widgets and the floating icons
(all below), and it records visits (`_recordVisit`, `_loadVisitDays`, storage file `/visit_days.json` L8557).

### 4.2 Collector rank modal (`_showRankModal` + `_buildRankRow`, home_screen; names produced by `_getCollectorRankDetails` in collection_stats.dart)

Five thresholds and four names exist. [CONFIRMED strings, [INFERRED] pairing]

| Threshold | Evidence |
|---|---|
| `0-9 magazines` | L15454 @477160 |
| `10-24 magazines` | L3359 @154621 |
| `25-49 magazines` | L13476 @428523 |
| `50-99 magazines` | L10700 @359566 |
| `100+ magazines` | L6235 @224919 |

| Rank name | Evidence |
|---|---|
| `Stitch Starter` | L2137 @121869 |
| `Fabric Fanatic` | L10357 @339059 |
| `Sartorial Stylist` | L3266 @152470 |
| `Design Diva` | L13375 @426158 |

**Open discrepancy:** 5 thresholds, 4 names. I searched exhaustively for a fifth name (all 2-word and
3-word Title Case strings, all single Title Case words, all caps strings) and there is none. Either one
name is reused, or the top or bottom tier is rendered without a name. The runtime agent should read the rank
modal directly. [CONFIRMED that no fifth name string exists in the snapshot]

### 4.3 Collection stats (`collection_stats.dart`, @517450674) and progress (`collection_progress.dart`, @516108974)

All of these end in `: ` or start with a space, so they are concatenated with values at runtime.

| Text (exact, note the trailing space) | Evidence | Confidence |
|---|---|---|
| `Total Magazines: ` | L6383 @228549 | [CONFIRMED] |
| `Owned: ` | L12150 @396282 | [CONFIRMED] |
| `Missing: ` | L12196 @397325 | [CONFIRMED] |
| `Completion: ` | L13405 @426811 | [CONFIRMED] |
| `%` | 1 char, absent from libapp_strings.txt; @7729 | [CONFIRMED present] |
| `Latest Addition: ` | L2510 @131662 | [CONFIRMED] |
| `Oldest Issue: ` | L10209 @335438 | [CONFIRMED] |
| `Days Visited: ` | L3220 @151334 | [CONFIRMED] |
| ` out of ` | L16347 @499270 | [CONFIRMED] |
| ` (all ` and ` owned)` | L2204 @123383, L2525 @131909 | [CONFIRMED] |

`_buildStatRow` and `_buildImage` in collection_stats confirm a labelled row layout with an icon/image per
row [CONFIRMED]. The ` (all ` / ` owned)` pair reads like `"<n> out of <m> (all <k> owned)"` or
`"Completion: <p>% (all <k> owned)"` [GUESS on exact assembly].

### 4.4 Bottom navigation (`bottom_navigation.dart`)

Per the tour text (4.9) the five destinations are, in order: **Home**, **Search**, **Dancing Dress**
(add an issue), **Calendar** (yearly tracking), **Settings** [CONFIRMED by the tour bullets]. Only `Home`
exists as a standalone label literal (L9569); the other four items are icon-only, or their labels are drawn
from assets. Icon assets referenced: `assets/icon/dress.png` L4885, `assets/icon/searching.png` L12091,
`assets/icon/magazine.png` L13692, `assets/icon/coffee-cup.png` L8011, `assets/icon/lipstick.png`
(two-byte string, @263034, **absent from libapp_strings.txt**).

### 4.5 Select year screen (`select_year_screen.dart`, @468186903)

| Text | Evidence | Confidence |
|---|---|---|
| `Tap a year \nto revisit every moment beautifully organized \nall in one place` (one literal, two embedded newlines, note the trailing spaces before each `\n`) | L4381 + L4382 + L4383, @179144 | [CONFIRMED text] |
| `Add Year` | L10743 | [INFERRED] |
| `No years available` | L15190 @470360 | [CONFIRMED empty state] |
| `This year already has 12 issues!` | L7570 @258086 | [CONFIRMED validation] |
| `You must add issues one by one after 2025!` | L13593 @431238 | [CONFIRMED validation] |

### 4.6 Browse magazines screen (`browse_magazines_screen.dart`, @465443711)

| Text | Evidence | Confidence |
|---|---|---|
| `Browse Issues` | L8919 | [INFERRED title] |
| `Tap a year, meet its issues \ntwelve chances to judge a cover by it` (one literal with embedded newline) | L8961 + L8962, @294189 | [CONFIRMED text] |
| `No magazines for ` (trailing space + year) | L14553 @454385 | [CONFIRMED template] |
| ` magazines for ` | L13182 @421241 | [CONFIRMED template] |
| `Added to your collection!` | L14921 @463454 | [CONFIRMED snackbar] |
| `Magazine removed!` | L13340 @425244 | [CONFIRMED snackbar] |
| `This issue already exists!` | L4724 @187589 | [CONFIRMED validation] |
| `Please select an issue and a valid year!` | L6810 @239124 | [CONFIRMED validation] |
| `Please select a valid issue and year (2000-` (truncated literal, concatenated with an upper bound then presumably `)`) | L3374 @154915 | [CONFIRMED template] |

This screen has a grid/list toggle persisted via `_loadViewPreference` / `_saveViewPreference` and pref key
`isGridView` L4814 [CONFIRMED], and fires confetti via `_checkAndTriggerConfetti` when a year completes
[CONFIRMED, see `Confetti triggered for year ` L10151].

### 4.7 Owned / Missing screens (@466417668, @467438405)

| Text | Evidence | Confidence |
|---|---|---|
| `No owned magazines` | L14617 @455877 | [CONFIRMED empty state] |
| `No missing magazines` | L5637 @210423 | [CONFIRMED empty state] |
| `OWNED`, `MISSING` | section 2 | [INFERRED] |

### 4.8 Magazine issue detail (`magazine_issue_detail_screen.dart`, @476342565) and gallery ("vault", `gallery_screen.dart`, @477102079)

| Text | Evidence | Confidence |
|---|---|---|
| `Upload Image` | L15846 | [INFERRED] |
| `No images uploaded yet.` | L6540 @232587 | [CONFIRMED empty state, issue detail] |
| `No images in the vault yet.` | L4333 @177948 | [CONFIRMED empty state, gallery] |
| `Image uploaded successfully!` | L14700 @457869 | [CONFIRMED snackbar] |
| `Image deleted from vault!` | L9292 @301722 | [CONFIRMED snackbar] |
| `Failed to delete image!` | L5968 @218107 | [CONFIRMED snackbar] |
| `Image not found` | L10471 @353952 | [CONFIRMED] |
| `No file selected.` | L12476 @404773 | [CONFIRMED, file/image picker cancelled] |
| `Magazine not found!` | L4009 @170532 | [CONFIRMED] |
| `Magazine not found` | L6040 @219996 | [CONFIRMED, variant without `!`] |
| `Are you sure you want to delete this issue?` | L12712 @410319 | [CONFIRMED confirm dialog] |
| `Evaluate Condition for ` + title | L11108 | [CONFIRMED] |
| `Rate the condition from 1 (Worn) to 10 (Mint)` | L6284 | [CONFIRMED] |
| `Condition set to ` | L13557 @430456 | [CONFIRMED, snackbar or log] |
| `Invalid image dimensions.` | L13689 @433327 | [INFERRED, may be framework] |
| `Invalid image path (file does not exist): ` | L12222 @397917 | [CONFIRMED, likely a log] |

Condition vocabulary [CONFIRMED]: the migration SQL maps `'Mint'` to 10, `'Good'` to 7, `'Worn'` to 3
(L3377 to L3379). So the user-visible words for condition are **Mint**, **Good**, **Worn** plus a 1 to 10
numeric score. Uploaded images live under `/magazine_images/<id>` (L4163, L8158) and the cover placeholder
is `assets/covers/placeholder.jpg` L14855.

### 4.9 Tour modal (`floating_background.dart`, @514513482) - TWO-BYTE STRINGS, NOT IN libapp_strings.txt

These are the single most valuable recoveries in this slice, and `strings` could not see any of them.
Both are single literals with embedded newlines and U+2022 bullets. [CONFIRMED, decoded from UTF-16LE]

Title: `Burda Style Tour` (L13366).

Block 1, under the `Bottom Navbar:` header, at **@140325**:

```
• Home: View your collection stats.
• Search: Find specific magazine issues.
• Dancing Dress: Adding a new issue.
• Calendar: Yearly Tracking Progress.
• Settings: Tweak your preferences.
```

Block 2, under the `Floating Icons:` header, at **@466620**:

```
• Magnifying Glass: Search Issues by entering number and a year (2/2024).
• Coffee Cup: Buy me a digital coffee.
• Phone: Coming Soon.
```

This confirms the search input format is `<issue number>/<year>`, e.g. `2/2024` [CONFIRMED], and that the
three floating icons are magnifying glass (search), coffee cup (donation joke) and phone (`_onMapTap`
internally, labelled "Phone" to the user, shows the Coming Soon / Under Construction modal).

### 4.10 "Coming Soon" / Under Construction modal - TWO-BYTE STRING, NOT IN libapp_strings.txt

At **@330165**, one literal [CONFIRMED]:

```
🚧 Under Construction! 🚧

This feature is currently just chilling in development limbo. Soon™ it will rise like a majestic phoenix or at least show up properly.
```

(Trailing newline included. Emoji is U+1F6A7 twice, and `Soon™` uses U+2122.) The short label
`Coming Soon` (L11388) is the collapsed/teaser form.

### 4.11 Settings screen (`settings_screen.dart`, @469241397)

Five sections, matching the five animation controllers `_theme`, `_quotes`, `_privacy`, `_data`, `_about`.

| Section | Header | Body / description | Evidence |
|---|---|---|---|
| Screen intro | - | `The settings are intuitively designed \nallowing you to personalize your experience \nwith ease and precision` (one literal, embedded newlines, trailing spaces before each `\n`) | L3700 + L3701 + L3702, @163084 [CONFIRMED text] |
| Theme | `Theme` L6210 | `Tailor your app’s color theme to align with your daily workflow and preferences` (**two-byte string, U+2019 apostrophe, NOT in libapp_strings.txt**) | @210731 [CONFIRMED] |
| Quotes | `Enable Quotes` L6195 | `This is the home screen quotes and will rotate forever` | L14540 @454129 [CONFIRMED] |
| Privacy | `Privacy & Security` L10691 | `View your privacy and security settings` L4374 @178857, plus the modal body below | [CONFIRMED] |
| Data | `Data Management` L15549 | `Export or upload your magazine data for seamless sharing and collaboration` | L7816 @264137 [CONFIRMED] |
| About | `About Burda Style` L9880 | `Learn more about Burda Style and its version` L11524 @380716, plus the modal body below | [CONFIRMED] |

Theme swatch labels: `RED PINK ORANGE GREEN BLUE PURPLE MAROON MELLON` (section 2).

**Privacy modal body - TWO-BYTE STRING, NOT IN libapp_strings.txt.** At **@470799**, one literal
[CONFIRMED]. This is a deliberate joke and explains the otherwise alarming CAMERA permission:

```
The data this app uses? It’s already in your storage. Now, I own everything you type, click, share, and see.

Maybe I’m even watching you through your camera right now. 

I’m always here.
```

(Note the trailing space after "right now." and the U+2019 apostrophes.)

**About modal body - TWO-BYTE STRINGS, NOT IN libapp_strings.txt.** Stored as four adjacent literals at
@141917, @141953, @141985, @142441, @143115, i.e. header + version + three paragraphs [CONFIRMED]:

```
About Burda Style
Version: 1.8.1

Welcome to Burda Style, a premier digital companion for fashion enthusiasts and collectors. This app, now in its 17th iteration, serves as a precise timekeeping tool while preserving the rich heritage of Burda’s iconic designs

Crafted with dedication, Burda Style is more than a utility - it is a trusted archive of patterns, a curator of collections, and a resource for creativity. Designed to endure, it ensures that every detail is securely stored, allowing users to track and manage their treasured designs with ease, no matter where their journey takes them

For the discerning collector, knowledge is invaluable, and this app remains a steadfast tool. With every update, it continues to refine the user experience, keeping the legacy of Burda Style firmly in hand.
```

Details worth preserving verbatim: "now in its 17th iteration", the missing full stops at the end of the
first two paragraphs, `Burda’s` with a curly apostrophe, and the literal `" - "` in "more than a utility -
it is".

Data Management outcomes [CONFIRMED]:

| Text | Evidence |
|---|---|
| `EXPORT` / `IMPORT` buttons | section 2 |
| `Exported to ` (+ path) | L9692 @322264 |
| `Export cancelled.` | L15672 @482250 |
| `Imported successfully!` | L11459 @377036 |
| `Error exporting: ` | L13547 @430251 |
| `Error importing: ` | L16563 @504681 |
| `Error sharing: ` | L10789 @361592 |

Export target [CONFIRMED]: file name `magazines_export.json` L13528, path fragment
`/magazines_export.json` L3941, default directory `/storage/emulated/0/Download` L11009.

Share sheet copy [CONFIRMED], assembled from fragments:

| Fragment (exact) | Evidence |
|---|---|
| `Check out my magazine collection!` | L10016 @329987 |
| `My Burda Style Collection for ` (+ year) | L14961 @464371 |
| `I have ` | L2370 @127831 |
| `You have ` | L13856 @437506 |
| ` owned magazines.` | L2208 @123420 |
| ` in my Burda Style collection!` | L2811 @139047 |
| ` magazines:` | L11672 @384625 |

Likely assembly [INFERRED]: `"My Burda Style Collection for <year>"` + newline + `"I have <n> owned
magazines."` / `"<n> magazines:"` + a list, with `" in my Burda Style collection!"` used for a single-issue
share. `_shareMagazines` L6240 confirms a share path distinct from export.

### 4.12 Notes screen (`notes_screen.dart`, @470264457)

| Text | Evidence | Confidence |
|---|---|---|
| `Add Note` | L7372 | [INFERRED] |
| `Add a new note!` | L13796 @435979 | [CONFIRMED, empty state or CTA] |
| `Note added!` | L13485 @428740 | [CONFIRMED snackbar] |
| `Note deleted!` | L14244 @446557 | [CONFIRMED snackbar] |
| `NOTES` | section 2 | [INFERRED] |
| `Title` / `Content` | L5371 / L4846 | [GUESS field labels; the notes table columns are `title` and `content`, L9159 to L9160] |

Notes live in a separate SQLite file `notes.db` L6925 with table `notes(id TEXT PRIMARY KEY, title TEXT,
content TEXT, date TEXT)` [CONFIRMED L9157 to L9161]. A `date INTEGER` variant also exists (L9917 to L9921),
evidence of a schema change across versions.

### 4.13 Quote display (`quote_display.dart`, @513339066)

| Text | Evidence | Confidence |
|---|---|---|
| `No quotes available.` | L16253 @496985 | [CONFIRMED empty state] |
| `Error loading quotes: ` | L8536 @283808 | [CONFIRMED, log] |

Quote bodies themselves are **not** in the snapshot; they come from `assets/quotes.json` L9171 (68 entries,
`{type, content}`) [CONFIRMED]. `_GlitchTextState` and `_glitchOffsets` mean the quote is rendered with a
chromatic glitch effect [CONFIRMED].

### 4.14 Magazine card (`magazine_card.dart`, @501378081 / L9990)

The card opens a "result modal" with heart (own/unown), condition and trash actions [CONFIRMED from the log
strings in section 5]. User-visible strings attributable here:

| Text | Evidence | Confidence |
|---|---|---|
| `Are you sure you want to delete this issue?` | L12712 | [INFERRED, `_showDeleteModal`] |
| `Magazine removed!` | L13340 | [INFERRED] |
| `Added to your collection!` | L14921 | [INFERRED] |
| `WEAR` | L3315 | [GUESS, condition action label on the card] |

### 4.15 Search modal (home screen, `_showSearchModal`)

| Text | Evidence | Confidence |
|---|---|---|
| `SEARCH` | L8522 | [INFERRED] |
| `Please select an issue and a valid year!` | L6810 | [CONFIRMED] |
| `Please select a valid issue and year (2000-` + bound | L3374 | [CONFIRMED] |
| `Magazine not found!` | L4009 | [CONFIRMED] |
| `Year: ` | L4764 | [INFERRED] |
| Input format `<issue>/<year>`, example `2/2024` | tour bullet @466620 | [CONFIRMED] |

---

## 5. Format templates (concatenated at runtime)

Every string below ends with a trailing space, a `: `, or starts with a space or comma. They are string
concatenation fragments, so a rebuild must reproduce the surrounding punctuation exactly. Exact text is from
the byte-level extraction, which preserves trailing whitespace that libapp_strings.txt visually loses.

User-facing templates: `Days Visited: `, `Total Magazines: `, `Owned: `, `Missing: `, `Completion: `,
`Latest Addition: `, `Oldest Issue: `, ` out of `, ` (all `, ` owned)`, `Evaluate Condition for `,
`No magazines for `, ` magazines for `, `Exported to `, `My Burda Style Collection for `, `I have `,
`You have `, ` owned magazines.`, ` in my Burda Style collection!`, ` magazines:`, `Year: `,
`Please select a valid issue and year (2000-`, `Condition set to `, `%`.

Developer-only templates (see section 6): everything of the form `Error <x>: `, `, <field>: `,
`<Action> for magazine: `.

---

## 6. Debug prints and developer logs (separate, as requested)

These are `print`/`debugPrint` calls left in the release build. They are not UI, but they reveal logic, so I
list them in full. All [CONFIRMED present]; all are plain `print` output (the snapshot contains
`'print' is not supported` L4498, which is the dart:io fallback, and the app strings clearly read as log
lines).

### 6.1 Startup, database and migrations (`database_service.dart`, `magazine_provider.dart`)

`Initializing database at path: ` L3264, `Initializing database at: ` L5776, `Database opened, verifying
schema` L2382, `Magazines table schema: ` L5901, `Creating new database with version ` L13423, `Upgrading
database from version ` L9671, `Finished loading initial data` L13617, ` magazines from JSON` L5374,
`Loaded ` L5182, `Magazines loaded in initState: ` L15101.

Migration trace, which pins the schema history exactly [CONFIRMED]:
- `Applying migration for version 2: Creating notes table` L6197
- `Applying migration for version 3: Adding dateAdded and condition columns` L9633
- `Applying migration for version 4: Adding conditionScore and migrating data` L2727
- `Applying migration for version 5: Ensuring conditionScore column exists` L4545
- `Applying migration for version 6: Adding uploadedImages column` L11630
- `Adding condition column` L4322, `Adding dateAdded column` L15674, `Adding conditionScore column` L16507,
  `Adding uploadedImages column` L4715
- `condition column already exists, skipping addition` L5377, `dateAdded column already exists, skipping
  addition` L6092, `conditionScore column already exists, skipping addition` L8330, `uploadedImages column
  already exists, skipping addition` L15150
- `condition column does not exist, skipping condition to conditionScore migration` L10723
- `Migrating condition to conditionScore` L5886
- `Creating temporary table for schema update` L6767, `Copying data to temporary table` L15561,
  `Dropping old table and renaming temporary table` L2635

### 6.2 CRUD logs

`Added magazine: ` L5370, `Updated magazine: ` L16282, `Deleted magazine: ` L7782, `Deleted magazine with
id: ` L9652, `Magazine found: ` L7590, `Magazine not found for id: ` L4036, `Magazine not found: ` L9797,
`Toggling ownership for magazine: ` L7398, `Successfully toggled ownership for magazine: ` L5079,
`, current isOwned: ` L7920, `, new isOwned: ` L10045, `, isOwned: ` L8002, `Setting condition for magazine:
` L10948, `Successfully set condition for magazine: ` L13650, `Selected condition score: ` L2896,
`, conditionScore: ` L2814, `, score: ` L15980, `, title: ` L14218, `, year: ` L9757, `id: ` L7343,
`Note inserted: ` L16053, `Database is null, cannot load notes` L6083, `Database is null, cannot add note`
L12023, `Database is null, cannot delete note` L12465, `Owned Count: ` L12417, `Owned Count in HomeScreen: `
L13004, `, Missing Count: ` L11107, ` magazines for year ` L10205.

Errors: `Error adding magazine: ` L3971, `Error deleting magazine: ` L3577, `Error loading magazines: `
L3584, `Error loading magazines by year: ` L13260, `Error toggling ownership for magazine ` L10330, `Error
setting condition for magazine ` L5404, `Error inserting note: ` L5945, `Error in FutureBuilder: ` L12169,
`Error retrieving colors: ` L2246, `Error recording visit: ` L10966, `Error loading visit days: ` L12590,
`Error loading quotes: ` L8536, `Error loading ` L8012, `Error ` L10105, `Loading ` L10931.

### 6.3 Image / vault logs

`Loaded images for magazine ` L2124, `Images from disk for magazine ` L4928, `Images directory does not
exist for magazine ` L8912, `Added image to magazine: ` L11982, `Removed image from magazine: ` L11821,
`Error adding uploaded image to magazine ` L14307, `Error removing uploaded image from magazine ` L7571,
`Saved image to: ` L7033, `Picked image: ` L7612, `Error deleting image: ` L5737, `Failed to delete image: `
L8943, `Error loading image: ` L12937, `Error loading image at index ` L8220, `Rendering image at index `
L13631, `Error loading magazine image: ` L2492, `Error counting images: ` L10295, `Error loading image
count` L7737, `Total images counted: ` L12706, `Total images in FutureBuilder: ` L13765, `initState called,
initial _uploadedImages: ` L9323, `Loading images, reset _uploadedImages to empty` L8765, `,
_uploadedImages: ` L14590, `: uploadedImages=` L12921, `, new image count: ` L14738, `Invalid image path
(file does not exist): ` L12222.

### 6.4 Modal lifecycle logs (very revealing about the UI structure)

`Search modal opened` L6466, `Search modal closed` L10445, `Attempting to show search modal` L9669,
`Tapped outside search modal to close` L7894, `StatefulBuilder called - Search modal content active` L15514,
`Search button tapped!` L9265, `Search button pressed: Issue=` L4071, `, Year=` L6602, `Selected issue: `
L13213, `Selected issue ` L15382, `Selected year: ` L4073.

`Add modal opened` L7895, `Add modal closed` L6630, `Tapping outside add modal to close` L11751,
`StatefulBuilder called - Add modal content active` L11350, `Add magazine modal opened` L13212, `Add
magazine modal closed` L11465, `Tapping outside add magazine modal to close` L9593, `StatefulBuilder called
- Add magazine modal content active` L9262.

`Condition modal opened` L8494, `Condition modal closed` L16363, `Tapping outside condition modal to close`
L8786, `StatefulBuilder called - Condition modal content active` L7624.

`Result modal opened for magazine: ` L13000, `Result modal closed` L10011, `Tapped outside result modal to
close` L10534, `Tapped on result modal content - should not close` L12299, `Back button or tap outside
detected on result modal` L11711.

`Note details modal opened` L14624, `Note details modal closed` L13140, `Tapping outside note details modal
to close` L11043, `Add note modal opened` L16329, `Add note modal closed` L16103, `Tapping outside add note
modal to close` L13466.

`Tour modal opened` L15940, `Tour modal closed` L13986, `Map modal opened` L14074, `Map modal closed via
outside tap` L2636, `Coffee modal closed, total count: ` L14397.

### 6.5 Interaction logs

`Heart icon pressed for magazine: ` L3713, `Condition icon pressed for magazine: ` L4175, `Trash bin icon
pressed for magazine: ` L10034, `Cancel button pressed for magazine: ` L3848, `Delete button pressed for
magazine: ` L3904, `Coffee icon tapped` L9817, `Coffee icon in modal tapped` L16204, `Coffee click recorded,
count: ` L10346, `Coffee click recorded (modal), count: ` L10807, `Tour icon tapped` L8197, `Map icon
tapped` L7876, `Tapped icon: ` L16423, `Tap down on icon ` L13554, `Tap down detected at: ` L11567,
`Setting current index to: ` L15958, `Building widget, _isLoading: ` L10795, `, modal open: ` L11769,
`Building MagazineCard for magazine: ` L16559, `Confetti triggered for year ` L10151, `Error initializing
animations: ` L4037, `Error loading coffee-cup.png in modal: ` L5414, `Error loading searching.png: ` L13201.

### 6.6 Theme logs (`theme_provider.dart`, `main.dart`)

`Loaded theme: ` L3196, `Saved theme: ` L12744, `Theme changed to ` L5731, `Saved quotesEnabled: ` L2936,
`Quotes enabled: ` L5366, `, quotesEnabled: ` L14833, `Deep color retrieved: ` L4528, `Dark color
retrieved: ` L4659, `Main.dart theme colors - deepColor: ` L4589, `, lightColor: ` L5957, `deepBlack:`
L3930.

---

## 7. Storage keys and asset paths that constrain the copy [CONFIRMED]

Useful for the rebuild even though they are not copy: SharedPreferences / file keys `isGridView` L4814,
`quotesEnabled` L15369, `theme` L14705, `coffee_click_count` L4824, `coffee_click_days` L16480,
`/visit_days.json` L8557. Assets referenced from code: `assets/magazines.json` L3398, `assets/quotes.json`
L9171, `assets/covers/placeholder.jpg` L14855, `assets/icon/dress.png` L4885, `assets/icon/coffee-cup.png`
L8011, `assets/icon/searching.png` L12091, `assets/icon/magazine.png` L13692, `assets/icon/lipstick.png`
(@263034, two-byte string). Image directory `/magazine_images` L8158, export file
`magazines_export.json` L13528.

---

## 8. Strings deliberately EXCLUDED as Flutter/Material/package, not app copy

I checked each of these and found no evidence the app overrides them. Do not port them as app copy:
`Cancel` L7699, `Delete` L7647, `Close` L12009, `Back` L15694, `Copy` L12868, `Paste` L14412, `Cut`
(@ short), `Undo` L16488, `Redo` L5199, `Select all` L2526, `Select All` L6229, `More` L6253, `Share`
L2903, `Look Up` L8784, `Search Web` L2294, `Scan text` L2282, `Dismiss` L6328, `Open navigation menu`
L9367, `Close Bottom Sheet` L6171, `Navigator Scope` L5235, `Root Focus Scope` L8779, `BottomSheet child`
L7538, `Alert` L12479, `Stack Overflow` L14142 (a `StackOverflowError` message), `Asset not found` L6510,
`Unable to load asset: "` L10284, all month/weekday/era names and `1st quarter` to `4th quarter` (intl en
data), all `englishLike|dense|tall|blackMountainView|whiteMountainView <style> <year>` typography names, all
`material_color_utilities` scheme descriptions ("Pastel tokens, low chroma palettes (32).", "Tokens and
palettes match source color.", "Almost identical to Fidelity.", "All colors are grayscale, no chroma." and
friends), all `application/*`, `image/*`, `audio/*`, `video/*`, `text/*` MIME strings from `package:mime`,
all `Illegal IPv6/IPv4 ...` and `Invalid base64 ...` dart:core/dart:io messages, all `` `<plugin>` threw an
error: `` lines, all sqflite/SQL keyword strings, and the file_picker `PlatformFile(path ` / `, size: ` /
`, bytes: ` / `, readStream: ` / `, name: ` toString fragments. `SIZE` and `ENCRYPTED_SIZE` are plugin field
names (they have `get:`/`init:` twins), not labels.

---

## 9. Open questions the emulator run should settle

1. The fifth collector rank name: 5 thresholds, only 4 names exist in the binary. Which threshold shows
   which name, and what does the missing tier render?
2. Placement of `WEAR`, `FILL` and `SHOW`.
3. Whether the black theme has a caps swatch label (no `BLACK` literal exists).
4. Whether `Note`, `Title`, `Content`, `Save`, `Clear`, `About`, `Quote`, `Image`, `Year: ` are really on
   screen or are `toString()` artefacts.
5. Exact assembly of the stats line that uses ` out of `, ` (all ` and ` owned)`.
6. Exact assembly of the share text (which of `I have ` / `You have ` / ` magazines:` is used where).
7. Whether `Version: 1.8.1` is shown on its own anywhere in addition to inside the About body.
