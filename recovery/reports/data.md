# Burda Style - Data Layer & Business Logic Recovery Report

Slice: data layer and business logic (SQL, models, services, providers, persistence, stats).

Evidence base:
- `/home/x3kk3x/Desktop/Burda/recovery/libapp_strings.txt` (28406 lines, `strings` of `apk/lib/arm64-v8a/libapp.so`). Bare numbers below are line numbers in this file.
- `/home/x3kk3x/Desktop/Burda/recovery/apk/` (unzipped APK), `/home/x3kk3x/Desktop/Burda/assets/` (recovered assets).
- Raw binary greps against `apk/lib/arm64-v8a/libapp.so`.

Confidence markers: **[CONFIRMED]** direct string evidence with citation, **[INFERRED]** strong inference with stated reason, **[GUESS]** speculation.

The Dart snapshot is NOT obfuscated, so string literals, class names, method names and private-name library hashes survive. Note that the strings are stored in hash order, so physical adjacency in the dump means nothing except for multi-line literals, which are emitted as consecutive lines.

---

## 0. Library-hash map (how names were attributed to files)

Private Dart names carry a `@<libraryhash>` suffix that groups them by library. Mapping recovered by finding State-class names:

| hash | file | confidence | evidence |
|---|---|---|---|
| 463142880 | `main.dart` | [INFERRED] | `_AppWrapperState`, `SingleTickerProviderStateMixin`; `main.dart` is the only burda file with an app wrapper, and `Main.dart theme colors - deepColor: ` (4589) |
| 464176168 | `screens/home_screen.dart` | [CONFIRMED] | `_HomeScreenState` |
| 465443711 | `screens/browse_magazines_screen.dart` | [CONFIRMED] | `_BrowseMagazinesScreenState` |
| 466417668 | `screens/owned_magazines_screen.dart` | [CONFIRMED] | `_OwnedMagazinesScreenState` |
| 467438405 | `screens/missing_magazines_screen.dart` | [CONFIRMED] | `_MissingMagazinesScreenState` |
| 468186903 | `screens/select_year_screen.dart` | [CONFIRMED] | `_SelectYearScreenState` |
| 469241397 | `screens/settings_screen.dart` | [CONFIRMED] | `_SettingsScreenState` |
| 470264457 | `screens/notes_screen.dart` | [CONFIRMED] | `_NotesScreenState` |
| 471337958 | a `ChangeNotifier` provider (`providers/bottom_navigation_provider.dart` or `providers/magazine_provider.dart`) | [GUESS] | only the string `ChangeNotifier` is attributed to it |
| 472384369 | `providers/theme_provider.dart` | [CONFIRMED] | `_loadTheme`, `_saveTheme`, `_setPalette`, `_saveQuotesState` |
| 474340428 | `providers/dress_animation_provider.dart` | [INFERRED] | only `_animation`, `_controller`; the only burda non-widget class holding an animation is DressAnimationProvider, which also owns `get:isAnimating` (13426) |
| 475369058 | `models/note_provider.dart` | [CONFIRMED] | `_initDatabase`, `_loadNotes` |
| 476342565 | `screens/magazine_issue_detail_screen.dart` | [CONFIRMED] | `_MagazineIssueDetailScreenState` |
| 477102079 | `screens/gallery_screen.dart` | [CONFIRMED] | `_GalleryScreenState` |
| 499116846 | `services/database_service.dart` | [INFERRED] | `_initDatabase`, `_loadInitialData`; no third-party package in this build owns both names, and `note_provider.dart` already owns the other `_initDatabase` |
| 501378081 | `widgets/magazine_card.dart` | [INFERRED] | `_showDeleteModal`; MagazineCard is the delete entry point (`Building MagazineCard for magazine: ` 16559, `Delete button pressed for magazine: ` 3904, `Are you sure you want to delete this issue?` 12712) |
| 511253204 | `widgets/raining_hearts.dart` | [CONFIRMED] | `_RainingHeartsState` |
| 512325836 | `widgets/title_text.dart` | [CONFIRMED] | `_TitleTextState` |
| 513339066 | `widgets/quote_display.dart` | [CONFIRMED] | `_QuoteDisplayState`, `_GlitchTextState` (a second private widget in the same file) |
| 514513482 | `widgets/floating_background.dart` | [CONFIRMED] | `_FloatingBackgroundState` |
| 516108974 | `widgets/collection_progress.dart` | [CONFIRMED] | `_CollectionProgressState` |
| 517450674 | `widgets/collection_stats.dart` | [CONFIRMED] | `_CollectionStatsState` |

No private names were attributed to `models/magazine.dart`, `models/note.dart`, `models/quote.dart`, `providers/magazine_provider.dart`, `providers/bottom_navigation_provider.dart`, `utilities/year_browse_util.dart`, `widgets/bottom_navigation.dart`, `widgets/info_blocks.dart`. [INFERRED] those files have no private members that survived, i.e. they are plain public model/provider/util code.

---

## 1. SQL - complete reconstruction

### 1.1 Databases and files

| what | value | confidence | line |
|---|---|---|---|
| magazines DB filename | `magazines.db` | [CONFIRMED] | 15219 |
| notes DB filename | `notes.db` | [CONFIRMED] | 6925 |
| magazines DB schema version | **6** | [CONFIRMED] | migration log lines for versions 2,3,4,5,6 (6197, 9633, 2727, 4545, 11630) and no version 7 string exists |
| notes DB schema version | **1** | [GUESS] | no migration strings for notes.db |
| DB path source | `getDatabasesPath()` (2889), `getDatabasesPath is null` (16319) | [CONFIRMED] | joined with `path.join` |

Related debug strings: `Initializing database at path: ` (3264), `Initializing database at: ` (5776), `Creating new database with version ` (13423), `Upgrading database from version ` (9671), `Database opened, verifying schema` (2382), `Magazines table schema: ` (5901), `closing database` (8421).

### 1.2 `onCreate` for magazines.db (version 6 fresh install) [CONFIRMED 15170-15179]

```sql
          CREATE TABLE magazines (
            id TEXT PRIMARY KEY,
            title TEXT,
            year INTEGER,
            image TEXT,
            isOwned INTEGER,
            dateAdded TEXT,
            conditionScore INTEGER,
            uploadedImages TEXT
          )
```

Note: the fresh schema has **no `condition TEXT` column**. `condition` only exists on databases that came up through the v3 migration and is dropped again by the v4 rebuild.

`uploadedImages TEXT` is a real column that was not in the task brief.

### 1.3 `CREATE TABLE notes` - three distinct literals [CONFIRMED]

Three different source literals exist (the AOT compiler dedups identical strings, so three literals means three source sites):

- **Variant A** (2234-2239), 12-space indent on `CREATE`, 14 on columns, `date TEXT`:
```sql
            CREATE TABLE notes (
              id TEXT PRIMARY KEY,
              title TEXT,
              content TEXT,
              date TEXT
            )
```
- **Variant B** (9157-9162), 10-space indent, `date TEXT`:
```sql
          CREATE TABLE notes (
            id TEXT PRIMARY KEY,
            title TEXT,
            content TEXT,
            date TEXT
          )
```
- **Variant C** (9917-9922), 10-space indent, `date INTEGER`:
```sql
          CREATE TABLE notes (
            id TEXT PRIMARY KEY,
            title TEXT,
            content TEXT,
            date INTEGER
          )
```

[INFERRED] attribution by indentation depth: Variant A is nested one level deeper, matching the `onUpgrade` version-block that logs `Applying migration for version 2: Creating notes table` (6197). Variants B and C share the exact indentation of `CREATE TABLE magazines` (15170), i.e. an `onCreate` callback body. One of B/C is `magazines.db` `onCreate`, the other is `notes.db` `onCreate` in `models/note_provider.dart` (which owns `_initDatabase`, 475369058).

[INFERRED] the `date INTEGER` variant is a latent inconsistency in the original code: the Note date is written as a string everywhere else (see section 2.2). SQLite is dynamically typed so it worked anyway.

### 1.4 `onUpgrade` migration chain [CONFIRMED]

Exact log strings, in version order:

| ver | log string | line | statements |
|---|---|---|---|
| 2 | `Applying migration for version 2: Creating notes table` | 6197 | `CREATE TABLE notes (...)` Variant A |
| 3 | `Applying migration for version 3: Adding dateAdded and condition columns` | 9633 | see 1.5 |
| 4 | `Applying migration for version 4: Adding conditionScore and migrating data` | 2727 | see 1.6 |
| 5 | `Applying migration for version 5: Ensuring conditionScore column exists` | 4545 | idempotent re-add of `conditionScore` |
| 6 | `Applying migration for version 6: Adding uploadedImages column` | 11630 | see 1.7 |

The migration code is **guarded and idempotent** - it reads `PRAGMA table_info(magazines)` (13343) and skips work. Guard log strings:
- `dateAdded column already exists, skipping addition` (6092) / `Adding dateAdded column` (15674)
- `condition column already exists, skipping addition` (5377) / `Adding condition column` (4322)
- `conditionScore column already exists, skipping addition` (8330) / `Adding conditionScore column` (16507)
- `uploadedImages column already exists, skipping addition` (15150) / `Adding uploadedImages column` (4715)
- `condition column does not exist, skipping condition to conditionScore migration` (10723)

`PRAGMA user_version` (9820) and `PRAGMA user_version = ` (15087) are sqflite internals, not app code. [INFERRED]

### 1.5 Version 3 statements [CONFIRMED]

```sql
ALTER TABLE magazines ADD COLUMN dateAdded TEXT          -- 5221
ALTER TABLE magazines ADD COLUMN condition TEXT          -- 10197
UPDATE magazines SET dateAdded = ? WHERE dateAdded IS NULL   -- 2618 (note the trailing space in the literal)
UPDATE magazines SET condition = ? WHERE condition IS NULL   -- 6072
```
[INFERRED] the `?` for `dateAdded` is `DateTime.now().toIso8601String()` (14025) and the `?` for `condition` is a default label, most likely `'Good'` [GUESS].

### 1.6 Version 4 statements - condition to conditionScore + table rebuild [CONFIRMED]

```sql
ALTER TABLE magazines ADD COLUMN conditionScore INTEGER   -- 3163
```
```sql
              UPDATE magazines
              SET conditionScore = CASE
                WHEN condition = 'Mint' THEN 10
                WHEN condition = 'Good' THEN 7
                WHEN condition = 'Worn' THEN 3
                ELSE NULL
              END
```
(3375-3381, logged by `Migrating condition to conditionScore` 5886)

Then the column-drop rebuild (SQLite before 3.35 cannot `DROP COLUMN`), with its progress log strings:

1. `Creating temporary table for schema update` (6767)
```sql
            CREATE TABLE magazines_temp (
              id TEXT PRIMARY KEY,
              title TEXT,
              year INTEGER,
              image TEXT,
              isOwned INTEGER,
              dateAdded TEXT,
              conditionScore INTEGER
            )
```
(14946-14954)

2. `Copying data to temporary table` (15561)
```sql
            INSERT INTO magazines_temp (id, title, year, image, isOwned, dateAdded, conditionScore)
            SELECT id, title, year, image, isOwned, dateAdded, conditionScore
            FROM magazines
```
(6869-6871)

3. `Dropping old table and renaming temporary table` (2635)
```sql
DROP TABLE magazines                              -- 7777
ALTER TABLE magazines_temp RENAME TO magazines    -- 5265
```

Result: `condition TEXT` is gone after v4, only `conditionScore INTEGER` remains. `magazines_temp` has **no** `uploadedImages` column, which is why v6 adds it afterwards.

### 1.7 Version 6 statements [CONFIRMED]

```sql
ALTER TABLE magazines ADD COLUMN uploadedImages TEXT              -- 10069
UPDATE magazines SET uploadedImages = ? WHERE uploadedImages IS NULL  -- 8310
```
[INFERRED] the `?` is `'[]'` (empty JSON array), because the column holds a JSON-encoded list (see 2.1) and `jsonEncode`/`jsonDecode` are both present (2257, 7019).

### 1.8 CRUD - not raw SQL

Reads/writes other than the above go through the sqflite helper API, not raw SQL. Evidence: only two where-clause literals exist, `id = ?` (11997) and `year = ?` (3955); `whereArgs` (6377), `ConflictAlgorithm` (8726) and `ConflictAlgorithm.` (13363) are present; the fragments `DELETE FROM ` (12605), `) VALUES (` (11732), ` = NULL` (11349), `OR IGNORE`/`OR REPLACE`/`OR ABORT`/`OR FAIL`/`OR ROLLBACK` (6710, 10217, 14894, 11652, 7418), `BEGIN EXCLUSIVE` (12447) are sqflite's own query builder, not app literals. [CONFIRMED]

So: `db.query('magazines')`, `db.query('magazines', where: 'year = ?', whereArgs: [year])`, `db.insert('magazines', map, conflictAlgorithm: ConflictAlgorithm.replace)`, `db.update('magazines', map, where: 'id = ?', whereArgs: [id])`, `db.delete('magazines', where: 'id = ?', whereArgs: [id])`. [INFERRED]

Table-name literals present: `magazines` (8797), `notes` (10464). [CONFIRMED]

---

## 2. Models

### 2.1 `Magazine` (`models/magazine.dart`) [CONFIRMED name at 4336]

Fields, matching both the SQL schema and `assets/magazines.json`:

| field | type | JSON/map key | notes |
|---|---|---|---|
| `id` | `String` | `id` | format `"<issue>-<year>"`, e.g. `"1-2010"` [CONFIRMED from magazines.json] |
| `title` | `String` | `title` | format `"<issue>/<year>"`, e.g. `"1/2010"` [CONFIRMED] |
| `year` | `int` | `year` | [CONFIRMED 4847] |
| `image` | `String` | `image` | asset-relative, e.g. `"covers/1-2010.jpg"` [CONFIRMED] |
| `isOwned` | `bool` | `isOwned` | stored as INTEGER 0/1 in SQLite, `false`/`true` in JSON [CONFIRMED 9553] |
| `dateAdded` | `String` (ISO 8601) | `dateAdded` | [CONFIRMED 10479]; not present in magazines.json |
| `conditionScore` | `int?` | `conditionScore` | 1..10, nullable [CONFIRMED 13053] |
| `uploadedImages` | `List<String>` | `uploadedImages` | JSON-encoded string in SQLite [CONFIRMED 13232] |

- `copyWith` exists (16418) [CONFIRMED that the string exists; [INFERRED] that Magazine has it, since the task brief asks and many Flutter classes also own this name].
- `toJson` (10245) [CONFIRMED string exists; [INFERRED] use - `jsonEncode` calls `toJson` dynamically, so this may be dart:convert's own name].
- `toMap` / `fromMap` / `fromJson` do **not** appear as strings. [INFERRED] they exist in source but were inlined/renamed away; their absence is not evidence they are missing, because they are only ever called statically.
- Debug format strings that reveal the field set of a Magazine toString/log: `, title: ` (14218), `, year: ` (9757), `, isOwned: ` (8002), `, conditionScore: ` (2814), `: uploadedImages=` (12921), `, score: ` (15980). [CONFIRMED]

`dateAdded` format: `toIso8601String()` (14025) on write, `DateFormat('MMM dd, yyyy')` (13717, `DateFormat` 13739) on display. [INFERRED from the pair of strings]

`uploadedImages` encoding: JSON array of absolute file paths under the app documents directory. [INFERRED from `jsonEncode`/`jsonDecode` + `/magazine_images/` (4163) + `Invalid image path (file does not exist): ` (12222)]

### 2.2 `Note` (`models/note.dart`) [CONFIRMED name at 6917]

| field | type | key | confidence |
|---|---|---|---|
| `id` | `String` | `id` | [CONFIRMED schema] |
| `title` | `String` | `title` | [CONFIRMED schema, 12194] |
| `content` | `String` | `content` | [CONFIRMED schema, 7865] |
| `date` | `String` (ISO 8601) | `date` | [CONFIRMED schema, 15299]; see 1.3 for the `date INTEGER` variant |

- Notes are **standalone**, not attached to a magazine. [CONFIRMED] the `notes` table has no foreign key or magazine column in any of the three `CREATE TABLE notes` literals, and the only where-clause literals in the binary are `id = ?` and `year = ?`.
- `id` is generated with `uuid` v4: `UuidV4` (15003), `package:uuid/v4.dart` (5662), `Uuid` (13742). `UuidV1` is also linked in (13369, 11959) but that is unavoidable when you import `package:uuid/uuid.dart`. [INFERRED that v4 is the one used]

### 2.3 `Quote` (`models/quote.dart`) [CONFIRMED name at 13112]

| field | type | key | confidence |
|---|---|---|---|
| `type` | `String` | `type` | [CONFIRMED from quotes.json] |
| `content` | `String` | `content` | [CONFIRMED from quotes.json] |

- Loaded from `assets/quotes.json` (9171), never persisted to a database. [CONFIRMED]
- All 68 entries in the shipped `quotes.json` have `type == "fact"`. [CONFIRMED - verified by parsing the asset] So `type` is currently a single-valued discriminator; it is [GUESS] whether the UI branches on it at all.
- `Error loading quotes: ` (8536), `No quotes available.` (16253). [CONFIRMED]

### 2.4 `condition` vs `conditionScore` - resolved [CONFIRMED]

- `condition` (`TEXT`) is the **legacy v3 representation**: three labels `'Mint'`, `'Good'`, `'Worn'` (3377-3379). It is dropped in v4 and does not exist in a fresh v6 database.
- `conditionScore` (`INTEGER`) is the **current representation**: a **1..10 scale**, proven by the UI copy `Rate the condition from 1 (Worn) to 10 (Mint)` (6284).
- Legacy mapping is exactly `Mint -> 10`, `Good -> 7`, `Worn -> 3`, anything else -> `NULL` (3377-3380).
- `NULL` means "not yet rated". [INFERRED from `ELSE NULL` and the nullable column]
- No 1-5 star scale exists, and no `Poor` label exists. `Worn` is the low label. [CONFIRMED]
- Related copy and logs: `Evaluate Condition for ` (11108), `Selected condition score: ` (2896), `Condition set to ` (13557), `Setting condition for magazine: ` (10948), `Successfully set condition for magazine: ` (13650), `Error setting condition for magazine` (5404), `Condition modal opened` (8494) / `closed` (16363), `Condition icon pressed for magazine: ` (4175), `StatefulBuilder called - Condition modal content active` (7624), `Tapping outside condition modal to close` (8786).

---

## 3. Services and providers

### 3.1 `DatabaseService` (`services/database_service.dart`, hash 499116846 [INFERRED])

Methods and members, all names [CONFIRMED] as strings; the attribution to this class is [INFERRED] from naming and from the log strings that accompany them:

| member | line | what it does |
|---|---|---|
| `get database` | 6231 | lazy singleton getter; `database` (9831) |
| `_initDatabase()` | hash 499116846 | `getDatabasesPath()` + `join` + `openDatabase(version: 6, onCreate:, onUpgrade:)`; logs `Initializing database at path: ` (3264) |
| `_loadInitialData()` | hash 499116846 | seeds from `assets/magazines.json`; logs ` magazines from JSON` (5374) and `Finished loading initial data` (13617) |
| `getAllMagazines()` | 12950 | `db.query('magazines')`; error `Error loading magazines: ` (3584) |
| `getMagazinesByYear(year)` | 5321 | `where: 'year = ?'`; error `Error loading magazines by year: ` (13260); logs ` magazines for year ` (10205) |
| `addMagazine(magazine)` | 5343 | insert; logs `Added magazine: ` (5370); error `Error adding magazine: ` (3971) |
| `updateMagazine(magazine)` | 4174 | update `where: 'id = ?'`; logs `Updated magazine: ` (16282) |
| `deleteMagazine(id)` | 9466 | delete `where: 'id = ?'`; logs `Deleted magazine: ` (7782) and `Deleted magazine with id: ` (9652); error `Error deleting magazine: ` (3577) |
| `toggleOwnership(id)` | 7467 | flips `isOwned`; logs `Toggling ownership for magazine: ` (7398), `, current isOwned: ` (7920), `, new isOwned: ` (10045), `Successfully toggled ownership for magazine: ` (5079); error `Error toggling ownership for magazine` (10330) |
| `setCondition(id, score)` | 4301 | sets `conditionScore`; logs at 10948 / 13650 / 15980 |
| `addUploadedImage(magazineId, path)` | 2705 | appends to the JSON list; logs `Added image to magazine: ` (11982), `, new image count: ` (14738); error `Error adding uploaded image to magazine` (14307) |
| `removeUploadedImage(magazineId, path)` | 5818 | removes from the JSON list; logs `Removed image from magazine: ` (11821); error `Error removing uploaded image from magazine` (7571) |
| `addNote(note)` | 12383 | insert into `notes`; logs `Note inserted: ` (16053); errors `Database is null, cannot add note` (12023), `Error inserting note: ` (5945) |
| `deleteNote(id)` | 3183 | delete from `notes`; error `Database is null, cannot delete note` (12465) |

`magazineId` (15446) is [INFERRED] the parameter name on the image methods and/or the per-magazine folder name.

Not-found paths: `Magazine not found` (6040), `Magazine not found!` (4009), `Magazine not found for id: ` (4036), `Magazine not found: ` (9797), `Magazine found: ` (7590).

### 3.2 `MagazineProvider` (`providers/magazine_provider.dart`) [CONFIRMED name at 4753]

`ChangeNotifier` (4728 `notifyListeners`). Members:

| member | line | notes |
|---|---|---|
| `loadMagazines()` | 13240 | logs `Magazines loaded in initState: ` (15101) |
| `loadMagazinesByYear(year)` | 14676 | |
| `get magazines` | 8797 | backing list |
| `get ownedCount` | 9912 | logs `Owned Count: ` (12417), `Owned Count in HomeScreen: ` (13004) |
| `get missingCount` | 6409 | logs `, Missing Count: ` (11107) |

[INFERRED] the provider also proxies `addMagazine` / `deleteMagazine` / `toggleOwnership` / `setCondition` / `addUploadedImage` / `removeUploadedImage` to `DatabaseService` and calls `notifyListeners()`; the screens' debug strings (`Heart icon pressed for magazine: ` 3713, `Trash bin icon pressed for magazine: ` 10034) sit in widgets, and there is no second copy of the CRUD names, so the widgets call the provider which calls the service.

Other strings in this area: `Magazine removed!` (13340), `Added to your collection!` (14921), ` magazines for ` (13182), `No magazines for ` (14553), `No owned magazines` (14617), `No missing magazines` (5637), `Error in FutureBuilder: ` (12169), `Error loading magazine image: ` (2492).

### 3.3 `NoteProvider` (`models/note_provider.dart`, hash 475369058) [CONFIRMED name at 13696]

| member | confidence | notes |
|---|---|---|
| `_initDatabase()` | [CONFIRMED] | opens `notes.db` (6925) with its own `CREATE TABLE notes` |
| `_loadNotes()` | [CONFIRMED] | error `Database is null, cannot load notes` (6083) |
| `addNote(...)` | [CONFIRMED 12383] | shares the name with DatabaseService |
| `deleteNote(...)` | [CONFIRMED 3183] | |
| `get notes` | [CONFIRMED 10464] | |

Note that `NoteProvider` lives in `models/`, not `providers/` - matching the brief's file list. [CONFIRMED]

Notes UI copy: `Add Note` (7372), `Add a new note!` (13796), `Note added!` (13485), `Note deleted!` (14244), `Add note modal opened` (16329) / `closed` (16103), `Tapping outside add note modal to close` (13466), `Note details modal opened` (14624) / `closed` (13140), `Tapping outside note details modal to close` (11043), private methods `_showAddNoteModal`, `_showNoteDetailsDialog` (hash 470264457) [CONFIRMED].

Sorting: no `orderBy` literal and no sort-key string exists for notes. [INFERRED] notes are sorted in Dart (or not at all) and the list order is insertion order from `db.query('notes')`. `mergeSort` (16503) is dart:collection's. **Uncertain** - see section 9.

### 3.4 `ThemeProvider` (`providers/theme_provider.dart`, hash 472384369)

| member | confidence | notes |
|---|---|---|
| `_loadTheme()` | [CONFIRMED] | logs `Loaded theme: ` (3196) |
| `_saveTheme()` | [CONFIRMED] | logs `Saved theme: ` (12744) |
| `_setPalette(...)` | [CONFIRMED] | selects a named palette |
| `_saveQuotesState()` | [CONFIRMED] | logs `Saved quotesEnabled: ` (2936) |
| `setTheme(...)` | [CONFIRMED 15883] | public; logs `Theme changed to ` (5731) |
| `toggleQuotes()` | [CONFIRMED 10185] | logs `Quotes enabled: ` (5366), `, quotesEnabled: ` (14833) |
| `deepColor` / `lightColor` / `darkColor` | [CONFIRMED 14043 / (`, lightColor: ` 5957) / 6073] | three exposed colors per palette; `Main.dart theme colors - deepColor: ` (4589), `Deep color retrieved: ` (4528), `Dark color retrieved: ` (4659), `Error retrieving colors: ` (2246) |

Palette value names (all [CONFIRMED] as exact strings): `deepRed` 2256, `darkRed` 15430, `lightRed` 11635, `deepOrange` 8289, `darkOrange` 2384, `lightOrange` (as `lightOrangeV` 8298, the trailing V is adjacent-string bleed), `deepGreen` 6017, `darkGreen` 2731, `lightGreen` 14408, `deepBlue` 11891, `darkBlue` 11684, `lightBlue` 9126, `deepPurple` 10980, `darkPurple` 15004, `lightPurple` 16139, `deepPink` 3421, `lightPink` 7496, `deepMaroon` 6488, `darkMaroon` 15362, `lightMaroon` 2767, `deepMellon` 4137, `darkMellon` 10831, `lightMellon` 3208, `darkBlack` 10433, `lightBlack` 13987, plus `softPink` (6919).
That is a `deep`/`dark`/`light` triplet per colour family: red, orange, green, blue, purple, pink, maroon, mellon (sic, "melon"), black. [CONFIRMED set, [INFERRED] the triplet structure]

### 3.5 `BottomNavigationProvider` (`providers/bottom_navigation_provider.dart`)

| member | confidence | notes |
|---|---|---|
| `setCurrentIndex(int)` | [CONFIRMED 7704] | logs `Setting current index to: ` (15958) |
| `get currentIndex` | [INFERRED] | the setter name implies it; `index` (493) exists but is generic |

Related: `Bottom Navbar: ` (14297). [CONFIRMED]

### 3.6 `DressAnimationProvider` (`providers/dress_animation_provider.dart`, hash 474340428 [INFERRED])

| member | confidence | notes |
|---|---|---|
| `get isAnimating` | [CONFIRMED 13426] | |
| `_controller`, `_animation` | [CONFIRMED hash 474340428] | holds an `AnimationController` |
| start/stop trigger | [GUESS] | no `startAnimation`/`stopAnimation` string is attributable; `Error initializing animations: ` (4037) exists |

Related asset: `assets/icon/dress.png` (4885), `assets/icon/doll.png` (3612), `assets/icon/dummy.png` (14382). [CONFIRMED]

---

## 4. Seeding, adding issues, barcode scanning

### 4.1 How `magazines.json` seeds the DB

[INFERRED, strong] **First-run seed only, not a merge on every launch.** Reasons:
- `_loadInitialData` (hash 499116846) is a private method called from `_initDatabase`, and the log ` magazines from JSON` (5374) plus `Finished loading initial data` (13617) form a single one-shot sequence.
- `Creating new database with version ` (13423) is sqflite's `onCreate` path. The seed is [INFERRED] performed from `onCreate`, so it runs once per installed database.
- There is **no** "merge", "sync", "new issues", or diff-related string anywhere in the binary, and no `SELECT ... NOT IN` or `INSERT OR IGNORE` app literal.
- There is no first-launch SharedPreferences flag (see section 5), which would be the alternative mechanism.

Consequence for the rebuild: an app upgrade that ships new covers in `magazines.json` would **not** import them into an existing database. [INFERRED]

Seed shape per row: `id`, `title`, `year`, `image`, `isOwned: false`; `dateAdded`, `conditionScore`, `uploadedImages` are not in the JSON and are therefore NULL/default at seed time. [CONFIRMED from `assets/magazines.json`]

### 4.2 Adding a custom issue

Entry points: `_showAddMagazineModal` exists in **five** files - home_screen (464176168), browse_magazines_screen (465443711), select_year_screen (468186903), settings_screen (469241397), notes_screen (470264457). `_showAddMagazineModal` and a separate `_showAddModal` flow both exist. [CONFIRMED]

Flow strings [CONFIRMED]: `Add magazine modal opened` (13212) / `closed` (11465), `StatefulBuilder called - Add magazine modal content active` (9262), `Tapping outside add magazine modal to close` (9593), `Add modal opened` (7895) / `closed` (6630), `StatefulBuilder called - Add modal content active` (11350), `Tapping outside add modal to close` (11751), `Selected issue: ` (13213), `Selected issue` (15382), `Selected year: ` (4073), `Add Year` (10743).

Validation messages, all [CONFIRMED]:

| message | line | meaning |
|---|---|---|
| `Please select an issue and a valid year!` | 6810 | both fields required |
| `Please select a valid issue and year (2000-` | 3374 | range message, string-concatenated with an upper bound and `)`; lower bound **2000** |
| `This issue already exists!` | 4724 | duplicate `id` check |
| `This year already has 12 issues!` | 7570 | max 12 issues per year |
| `You must add issues one by one after 2025!` | 13593 | the "Add Year" bulk path is capped at 2025; beyond that only single-issue adds |

[INFERRED] the upper bound concatenated after `(2000-` is the current year or a constant near 2025+, given the companion "after 2025" rule and that shipped covers end at 4/2025.

### 4.3 Cover image for a custom issue

[CONFIRMED] `image_picker` is used: `pickImage` (14106), `ImagePickerPlatform` (15441), `ImageSource` (10468), `getImageFromSource` (2595), `ImagePickerAndroid.` (3175), `` `image_picker_android` threw an error: `` (6984), `assets/covers/placeholder.jpg` (14855) as fallback.

[CONFIRMED] `assets/covers/placeholder.jpg` is referenced by Dart code but is **NOT bundled** - it is absent from `apk/assets/flutter_assets/assets/covers/` (184 files, none named placeholder) and absent from `AssetManifest.json` (248 entries, zero matches). So that fallback always threw `Unable to load asset: "` (10284). **Rebuild note: either ship a placeholder.jpg or handle the error.**

Camera: the APK declares `CAMERA` permission, and the `ImageSource` enum value names `gallery` (4845) and `camera` (11018) plus `CameraDevice` (4007) / `front` (7658) / `rear` (16570) are linked in. However, enum value names ship whenever the enum type is referenced at all, so this does **not** prove a camera option was offered in the UI. A capitalised `Camera` (4913) exists with no matching `Gallery` label, so it is [GUESS] whether the picker exposed both sources or gallery only.

### 4.4 Barcode scanning - **it does not exist in the Dart code** [CONFIRMED]

Direct binary greps over `apk/lib/arm64-v8a/libapp.so` return **zero** matches for every one of: `barcode`, `Barcode`, `mobile_scanner`, `MobileScanner`, `scanner`, `sensors_plus`, `accelerometer`, `permission_handler`, `Permission`.

Conclusion [CONFIRMED]: `mobile_scanner`, `sensors_plus` and `permission_handler` were declared in `pubspec.yaml` (hence the Android-side `GeneratedPluginRegistrant` entries and the `CAMERA` permission in the manifest) but **no Dart code ever imported or used them**, so they were tree-shaken out entirely. There is no EAN parsing, no add-on-digit parsing, no issue/year extraction from a barcode. The `scanCode` (16394) and `scan` (16080) strings are unrelated (`ScanChannelsToggle` 13358 is a Flutter keyboard key name; `_scanFlags` 91 and `scanCodeUnits` are dart:core internals).

For the rebuild: drop these three dependencies, or keep them as inert dependencies if the goal is byte-level pubspec fidelity. The `CAMERA` permission is still needed for `image_picker`.

---

## 5. SharedPreferences keys

All [CONFIRMED] as exact whole-line strings:

| key | line | type | stores |
|---|---|---|---|
| `theme` | 14705 | String | the selected palette name (one of the `deep*`/`dark*`/`light*` names in 3.4). Logged by `Loaded theme: ` / `Saved theme: ` / `Theme changed to `. [INFERRED on the value domain] |
| `quotesEnabled` | 15369 | bool | home-screen quote rotation on/off. `Enable Quotes` (6195) is the settings toggle label; `Saved quotesEnabled: ` (2936), `Quotes enabled: ` (5366). [CONFIRMED] |
| `isGridView` | 4814 | bool | browse-magazines grid vs list view. Read/written by `_loadViewPreference` / `_saveViewPreference` (hash 465443711 = browse_magazines_screen). [CONFIRMED] |
| `coffee_click_count` | 4824 | int | lifetime taps on the coffee-cup easter egg. `Coffee click recorded, count: ` (10346), `Coffee click recorded (modal), count: ` (10807), `Coffee modal closed, total count: ` (14397). [CONFIRMED] |
| `coffee_click_days` | 16480 | String or StringList | per-day coffee taps, feeding `Click of the day` (11303) and `, daily: ` (4508). [INFERRED on the encoding - most likely a JSON map/list of date keys] |

Accessors present: `getBool` (14440), `getInt` (10446), `getAll` (10703), `getInstance` (5302), plus the pigeon channel `SharedPreferencesApi.setBool` (12383 region). [CONFIRMED]

**No first-launch / onboarding / DB-seeded flag key exists.** [CONFIRMED by exhaustive negative grep of `firstLaunch`, `first_launch`, `isFirstRun`, `seeded`, `initialized`, `hasLaunched` and by the absence of any snake_case app key other than the two coffee keys.] The welcome copy `Welcome to Burda Style!` (13809) / `Track your magazine collection with ease.` (13810) is therefore [INFERRED] static home-screen copy, not a one-time onboarding gate.

**Not** in SharedPreferences: visit days. See 7.3.

---

## 6. Backup / restore / export / import / share

All in `screens/settings_screen.dart` (hash 469241397), private methods `_exportMagazines`, `_importMagazines`, `_shareMagazines` [CONFIRMED], grouped under the `Data Management` (15549) section with subtitle `Export or upload your magazine data for seamless sharing and collaboration` (7816) and the `_dataAnimationController`.

### 6.1 Export [CONFIRMED]

- File name: **`magazines_export.json`** (13528), written as `<dir>/magazines_export.json` (the literal `/magazines_export.json` at 3941 is the concatenated separator+name).
- Written with `writeAsString` (7190) after `jsonEncode` (2257).
- Directory: `getApplicationDocumentsDirectory()` (7869) / `getApplicationDocumentsPath` (10955), with `getTemporaryDirectory` (12999) / `getTemporaryPath` (8800) also linked. Error `Unable to get application documents directory` (15410), `Unable to get temporary directory` (16324).
- A destination is chosen with file_picker's `saveFile` (12148). [CONFIRMED]
- Messages: `Exported to ` (9692), `Export cancelled.` (15672), `Error exporting: ` (13547).
- Format [INFERRED]: a JSON array of magazine maps, i.e. the same shape as the `magazines` table rows including `dateAdded`, `conditionScore` and `uploadedImages`. There is no second export literal and no CSV/zip/db-copy string, so the DB file itself is not exported.

### 6.2 Import [CONFIRMED]

- `pickFiles` (3635) via `MethodChannelFilePicker` (4302), with `FileType` (15184) and `custom` (7596) plus the extension `json` (4245). [INFERRED] `FileType.custom, allowedExtensions: ['json']`.
- Read with `readAsString` (13663), parsed with `jsonDecode` (7019).
- Messages: `Imported successfully!` (11459), `No file selected.` (12476), `Error importing: ` (16563), `` `file_picker` threw an error: `` (7706).
- [INFERRED] import upserts rows with `ConflictAlgorithm.replace` (8726) since the only insert-conflict machinery present is sqflite's.

### 6.3 Share [CONFIRMED]

- `share_plus`: `shareXFiles` (2142), `shareFiles` (8860), `SharePlatform` (6779), `Share` (2903), `Share...` (6851), `ShareResult(raw: ` (5717), `get shareEnabled` (13785), `dev.fluttercommunity.plus/share/unavailable` (6142). `XFile`/`cross_file` and `mime` back it.
- Share copy: `Check out my magazine collection!` (10016), `My Burda Style Collection for ` (14961), ` in my Burda Style collection!` (2811), `I have ` (2370), `You have ` (13856), ` out of ` (16347), ` owned magazines.` (2208), `Burda Style Collection` (6761).
- [INFERRED] the share body is assembled roughly as `"I have <ownedCount> out of <total> ... in my Burda Style collection!"` and the subject/title as `"My Burda Style Collection for <year>"`. The exact assembly order is **uncertain**.
- Error `Error sharing: ` (10789).

---

## 7. Stats logic

### 7.1 Collection progress and stats widgets

- `widgets/collection_progress.dart` (516108974): `_CollectionProgressState` with a single `_controller`/`_animation` pair - an animated progress bar driven by `ownedCount / total`. [INFERRED]
- `widgets/collection_stats.dart` (517450674): `_CollectionStatsState` with `_buildStatRow`, `_buildImage`, `_getCollectorRankDetails`. [CONFIRMED]

Stat row labels, all [CONFIRMED]:

| label | line |
|---|---|
| `Total Magazines: ` | 6383 |
| `Owned Count: ` | 12417 |
| `Latest Addition: ` | 2510 |
| `Oldest Issue: ` | 10209 |
| `Days Visited: ` | 3220 |
| `, Missing Count: ` | 11107 |
| `Total images counted: ` | 12706 |
| `Total images in FutureBuilder: ` | 13765 |
| `Floating Icons: ` | 15599 |

`Latest Addition` / `Oldest Issue` are the "since"-style dates: [INFERRED] `Latest Addition` = max `dateAdded` among owned rows, `Oldest Issue` = min `year`/`id` among owned rows, both rendered with `DateFormat('MMM dd, yyyy')` (13717).

### 7.2 Collector rank (this is the "trophy") [CONFIRMED]

There is **no** trophy/achievement/badge system - direct greps for `trophy`, `achiev`, `badge`, `streak` return nothing. What exists is a single **collector rank** ladder, shown by `_showRankModal` / `_buildRankRow` (home_screen, 464176168) and computed by `_getCollectorRankDetails` (collection_stats, 517450674), under the heading `Rank Levels:` (14941).

Bands [CONFIRMED]:

| band label | line |
|---|---|
| `0-9 magazines` | 15454 |
| `10-24 magazines` | 3359 |
| `25-49 magazines` | 13476 |
| `50-99 magazines` | 10700 |
| `100+ magazines` | 6235 |

Rank names [CONFIRMED, exactly four found]:

| name | line |
|---|---|
| `Stitch Starter` | 2137 |
| `Sartorial Stylist` | 3266 |
| `Fabric Fanatic` | 10357 |
| `Design Diva` | 13375 |

Five bands, four names. `Coming Soon` (11388) is the most likely fifth-tier placeholder for `100+`. [GUESS] - see section 9. The band-to-name pairing is [INFERRED] as ascending in the order listed.

### 7.3 Days visited [CONFIRMED]

Stored as a **file**, not in SharedPreferences: `/visit_days.json` (8557) in the app documents directory, written with `writeAsString` / read with `readAsString`. Managed by `_recordVisit` and `_loadVisitDays` in home_screen (464176168). Errors: `Error recording visit: ` (10966), `Error loading visit days: ` (12590). Surfaced as `Days Visited: ` (3220). Format [INFERRED]: a JSON array of date strings, deduplicated per calendar day.

### 7.4 Missing magazines [CONFIRMED]

- `get missingCount` (6409) on MagazineProvider.
- `screens/missing_magazines_screen.dart` (467438405) shows `No missing magazines` (5637).
- [INFERRED] computed purely in Dart as the rows with `isOwned == false` (`total - ownedCount`), since there is no dedicated SQL for it.

### 7.5 Per-year counts and the year browser [CONFIRMED]

- `getMagazinesByYear` / `loadMagazinesByYear` (5321 / 14676).
- `utilities/year_browse_util.dart` exposes `showYearBrowseBottomSheet` (13383).
- `screens/select_year_screen.dart` (468186903) copy: `No years available` (15190), `Tap a year` (4381), ` to revisit every moment beautifully organized` (4382), `all in one place` (4383), `Tap a year, meet its issues` (8961), `twelve chances to judge a cover by it` (8962), `Browse Issues` (8919), ` magazines for year ` (10205), ` magazines for ` (13182), `No magazines for ` (14553).
- Completing a year fires confetti: `_checkAndTriggerConfetti`, `_confettiController` (browse_magazines_screen, 465443711), `Confetti triggered for year ` (10151). [CONFIRMED]

### 7.6 Image counts [CONFIRMED]

`_countTotalImages` (home_screen), `Total images counted: ` (12706), `Error counting images: ` (10295), `Error loading image count` (7737).

---

## 8. Per-magazine uploaded images (the "vault") [CONFIRMED]

Two-part storage:
1. **Files on disk**: `<applicationDocumentsDirectory>/magazine_images/` (4163, plus the bare `/magazine_images` at 8158), [INFERRED] one subfolder per `magazineId`, `.jpg` files (9972). Written with `writeAsBytes` (14587) after `readAsBytes` (14041); directory listed with `listSync` (14401); names likely stamped with `millisecondsSinceEpoch` (10416) [INFERRED].
2. **`magazines.uploadedImages` TEXT column**: the JSON-encoded path list.

Methods and screens:
- `services/database_service.dart`: `addUploadedImage` (2705), `removeUploadedImage` (5818).
- `screens/magazine_issue_detail_screen.dart` (476342565): `_loadImages`, `_pickAndSaveImage`, `_deleteImage`, `_showFullScreenImage`.
- `screens/gallery_screen.dart` (477102079): `_loadAllImages`, `_deleteImage`, `_showFullScreenImage`.
- `screens/home_screen.dart`: `_saveImage`, `_countTotalImages`.

Messages [CONFIRMED]: `Upload Image` (15846), `Image uploaded successfully!` (14700), `Image deleted from vault!` (9292), `Failed to delete image!` (5968), `No images in the vault yet.` (4333), `No images uploaded yet.` (6540), `Saved image to: ` (7033), `Picked image: ` (7612), `Image not found` (10471), `Invalid image path (file does not exist): ` (12222), `Images directory does not exist for magazine ` (8912), `Loaded images for magazine ` (2124), `Images from disk for magazine ` (4928), `Loading images, reset _uploadedImages to empty.` (8765), `initState called, initial _uploadedImages: ` (9323), `, _uploadedImages: ` (14590), `Rendering image at index ` (13631), `Error loading image at index ` (8220), `Error deleting image: ` (5737), `Failed to delete image: ` (8943), `Error loading image: ` (12937), `Cannot delete file` (14402), `Cannot copy file to '` (9718).

---

## 9. Explicit uncertainties

1. **Which `CREATE TABLE notes` literal belongs to which file.** Three literals exist (1.3). Indentation says Variant A is the v2 `onUpgrade` migration, but whether Variant B (`date TEXT`) or Variant C (`date INTEGER`) is `magazines.db`'s `onCreate` versus `notes.db`'s `onCreate` is unresolved. Rebuild recommendation: use `date TEXT` everywhere.
2. **`notes.db` schema version.** No migration string exists; version 1 is a guess.
3. **The `?` values in the v3 backfills.** `dateAdded = ?` is almost certainly `DateTime.now().toIso8601String()`; `condition = ?` is probably `'Good'` but could be `'Worn'` or `''`.
4. **The `?` value in the v6 `uploadedImages` backfill.** Probably `'[]'`, possibly `''`.
5. **The upper bound concatenated after `Please select a valid issue and year (2000-`.** Not recoverable from strings; likely the current year or 2025.
6. **The fifth rank name.** Five count bands, four rank names, plus an unattached `Coming Soon` (11388). Unresolved.
7. **Band-to-rank pairing direction.** Assumed ascending.
8. **Note sorting.** No `orderBy` and no comparator string; insertion order is the fallback assumption.
9. **`coffee_click_days` encoding.** A JSON map/list of dates is the assumption; could be a `StringList` pref.
10. **`visit_days.json` encoding.** JSON array of ISO dates assumed.
11. **Whether `Magazine` really has `toMap`/`fromMap`/`fromJson`/`copyWith`.** Those names are absent or ambiguous in the strings, because statically-called methods leave no name. The field set is certain; the exact constructor/serializer API is not.
12. **Share text assembly order** (6.3). The fragments are confirmed, the sentence is not.
13. **Whether `Quote.type` is branched on in the UI.** All 68 shipped quotes are `"fact"`.
14. **Whether the camera (as opposed to gallery) source was offered** for cover/vault images.
15. **`get currentIndex` on BottomNavigationProvider** is inferred from `setCurrentIndex` alone.
16. **Hash 471337958** (only `ChangeNotifier`) could not be assigned to a specific provider file.
17. **Whether `_loadInitialData` runs only in `onCreate`** or is also called defensively on every open. The absence of any first-launch flag and the presence of `Database opened, verifying schema` (2382) leave a small chance it re-checks and re-seeds an empty table on every launch.

---

## 10. Things the rebuild must not lose

- DB version **6** with the full 2 to 6 migration chain, guarded by `PRAGMA table_info(magazines)`. A new project could ship version 1 with the final schema, but then an existing user's `magazines.db` would never be migrated. Keep the chain.
- Two separate databases: `magazines.db` and `notes.db`.
- `uploadedImages` column and the `<docs>/magazine_images/` tree.
- `conditionScore` is 1..10, nullable, with the `Mint 10 / Good 7 / Worn 3` legacy mapping.
- `assets/covers/placeholder.jpg` is referenced but missing - fix or guard.
- `mobile_scanner`, `sensors_plus` and `permission_handler` are dead dependencies; there was never any barcode feature.
- The five SharedPreferences keys: `theme`, `quotesEnabled`, `isGridView`, `coffee_click_count`, `coffee_click_days`.
- `visit_days.json` and `magazines_export.json` file names.
