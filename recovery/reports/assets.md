# Burda Style - Asset and Seed Data Audit

Slice: asset and seed data audit. Nothing was modified. All paths absolute where it matters.

Audit target: `/home/x3kk3x/Desktop/Burda/assets/`
Reference: `/home/x3kk3x/Desktop/Burda/recovery/apk/assets/flutter_assets/`
Strings: `/home/x3kk3x/Desktop/Burda/recovery/libapp_strings.txt` (line numbers cited below)

## 0. Outcome first

- The asset set is **complete and exact**. 248 files on disk, 248 entries in the original
  `AssetManifest.json`, zero in one and not the other [CONFIRMED]. Spot md5 re-check on 8 files
  (4 covers incl. the PNG, both JSON, background, icon.png) all identical to the APK [CONFIRMED].
- `magazines.json` is internally consistent: 184 entries, no duplicate ids, no month gaps
  2010-2024, every `image` path resolves to a real file [CONFIRMED].
- **The brief's "10-2011.png anomaly" is not an orphan.** Entry index 21 explicitly points at
  `covers/10-2011.png`. There are zero unreferenced cover files and zero dangling cover
  references. The only irregularity is that one entry breaks the `covers/<id>.jpg` naming rule
  [CONFIRMED]. A rebuild must read `image` from JSON, not synthesise the `.jpg` path.
- **`assets/covers/placeholder.jpg` is referenced by Dart code (line 14855) but does not exist
  and never existed in the APK manifest either** [CONFIRMED]. This was a latent bug in the
  original app: the fallback path itself 404s. Flag for the rebuild.
- **`assets/images/background.png` (906 KB) is never referenced by any string literal in either
  `libapp.so`** [CONFIRMED]. 17 of the 42 icons are likewise never named. ~1.4 MB of dead assets.
- All 68 quotes are a single type, `"fact"` [CONFIRMED]. The model has a `type` field but the data
  never exercises it.
- Covers are 37.66 MB of the 42.26 MB asset payload and are already 96.9% incompressible in the
  APK zip. Compression numbers in section 7: a height cap of 900 px at 0.22 B/px saves ~17.4 MB
  (46%). Data only, no files changed.

---

## 1. magazines.json [CONFIRMED]

File: `/home/x3kk3x/Desktop/Burda/assets/magazines.json`, 23,137 bytes.
Format: JSON array, 2-space indent, LF line endings, 1,290 lines, no BOM, **no trailing
newline**, pure ASCII (0 non-ASCII chars).

### Shape

All 184 entries share the identical key order and value types [CONFIRMED]:

```json
{
  "id": "1-2010",          // String,  "<month>-<year>"
  "title": "1/2010",       // String,  "<month>/<year>"
  "year": 2010,            // int
  "image": "covers/1-2010.jpg", // String, relative to assets/
  "isOwned": false         // bool
}
```

Type histogram over all 184: `('str','str','int','str','bool')` x 184. Key order
`(id, title, year, image, isOwned)` x 184. No entry has extra or missing keys.

### Totals and range

| Metric | Value |
|---|---|
| Entries | 184 |
| First (array order) | `1-2010` |
| Last (array order) | `4-2025` |
| Distinct years | 16 (2010 - 2025) |
| Sorted ascending by (year, month)? | Yes, strictly |
| Duplicate `id` | none |
| Duplicate `title` | none |
| `isOwned: true` | **0** (all 184 are false) |

### Per year

| Year | Entries | Months present | Missing months |
|---|---|---|---|
| 2010 | 12 | 1-12 | none |
| 2011 | 12 | 1-12 | none |
| 2012 | 12 | 1-12 | none |
| 2013 | 12 | 1-12 | none |
| 2014 | 12 | 1-12 | none |
| 2015 | 12 | 1-12 | none |
| 2016 | 12 | 1-12 | none |
| 2017 | 12 | 1-12 | none |
| 2018 | 12 | 1-12 | none |
| 2019 | 12 | 1-12 | none |
| 2020 | 12 | 1-12 | none |
| 2021 | 12 | 1-12 | none |
| 2022 | 12 | 1-12 | none |
| 2023 | 12 | 1-12 | none |
| 2024 | 12 | 1-12 | none |
| 2025 | **4** | 1, 2, 3, 4 | 5, 6, 7, 8, 9, 10, 11, 12 |

15 complete years x 12 + 4 = 184. The only "gap" is the truncated final year, which is simply
where the collection data stopped [CONFIRMED]. This dates the seed data to roughly mid-2025
[INFERRED: the last issue present is 4/2025].

### Consistency checks

- `id` matches `^\d{1,2}-\d{4}$` for all 184 [CONFIRMED].
- `title` equals `<month>/<year>` derived from `id` for all 184 [CONFIRMED].
- `year` equals the year parsed from `id` for all 184 [CONFIRMED].
- Month is within 1-12 for all 184 [CONFIRMED].
- `image` equals `covers/<id>.jpg` for **183 of 184**. The one exception:

```json
{ "id": "10-2011", "title": "10/2011", "year": 2011,
  "image": "covers/10-2011.png", "isOwned": false }
```

  (array index 21). This is a **correct** reference: `covers/10-2011.png` exists on disk
  (376,524 bytes, 401x484, 8-bit RGBA PNG) [CONFIRMED].

### Cover cross-reference

| Check | Result |
|---|---|
| `image` paths that do not resolve under `assets/` | **0** |
| Files in `assets/covers/` | 184 |
| Cover files referenced by no entry | **0** |
| References with no file | **0** |

The cover directory and the JSON are in exact 1:1 correspondence [CONFIRMED]. This contradicts
the brief's expectation of an unreferenced `10-2011.png`; the correction is above.

### Rebuild notes

- `isOwned` in the JSON is pure seed state, always false. Ownership is held in the sqlite
  `magazines` table, which is what the app mutates [INFERRED: all seed values are false, and the
  Android side has a `magazines` table with an `isOwned` column per the brief]. A rebuild that
  re-seeds from this file must not clobber the user's DB.
- Do not compute the cover path from `id`. Read `image` verbatim, or `10/2011` loses its cover.

---

## 2. quotes.json [CONFIRMED]

File: `/home/x3kk3x/Desktop/Burda/assets/quotes.json`, 8,542 bytes.
Format: JSON array, 2-space indent, LF, 274 lines, no BOM, **no trailing newline**.
Non-ASCII: exactly **one** character, U+2019 RIGHT SINGLE QUOTATION MARK (in entry 30,
"Burda Style's patterns include..."). Every other apostrophe in the file is ASCII `'`
[CONFIRMED]. Preserve this byte-for-byte or that one string changes.

### Shape and counts

```json
{ "type": "fact", "content": "..." }
```

Key order `(type, content)` x 68, both String, no other keys [CONFIRMED].

| Metric | Value |
|---|---|
| Entries | 68 |
| Distinct `type` values | **1** |
| `type: "fact"` | 68 |
| Duplicate `content` | none |

The `Quote` class exists in the snapshot (`libapp_strings.txt:13112` = `Quote`) and the model file
is `lib/models/quote.dart`. The `type` field is therefore real but single-valued in the shipped
data. No other type literal (`tip`, `quote`, `trivia`, `inspiration`) appears anywhere in
`libapp_strings.txt` [CONFIRMED by exact-line grep]. A rebuild can keep `type` for fidelity but
must not assume it branches on anything.

Load error string: `libapp_strings.txt:8536` = `Error loading quotes: ` [CONFIRMED], so the loader
is wrapped in a try/catch that logs this prefix.

### All 68 entries verbatim

All have `"type": "fact"`. Index is array position (0-based).

| # | content |
|---|---|
| 0 | Aenne Burda founded her fashion magazine printing and publishing company in Offenburg, Germany, in 1949. |
| 1 | The first issue of Burda Moden magazine was published in 1950 with a circulation of 100,000. |
| 2 | In 1952, Burda Moden began including patterns for clothes, significantly boosting its popularity. |
| 3 | Burda Style is published in 17 languages and distributed in over 100 countries. |
| 4 | In 1987, Burda Moden became the first Western magazine to be published in the Soviet Union. |
| 5 | In 1994, Burda Moden became the first Western magazine to appear in the People's Republic of China. |
| 6 | Burda Style launched in the United States in 2013, in partnership with F+W Media. |
| 7 | Each issue of Burda Style contains patterns for every design featured that month. |
| 8 | Burda Style has become synonymous with sewing, patterns, and DIY skills. |
| 9 | Over 700 unique patterns (plus instructions) can be ordered/downloaded each season from BurdaStyle.de |
| 10 | Aenne Burda expanded her family business into women's magazine publishing in 1949. |
| 11 | The magazine was initially named 'Favorit' before being renamed to Burda Moden. |
| 12 | Burda Moden's circulation reached half a million by 1957. |
| 13 | Aenne Burda commissioned architect Egon Eiermann to design the first Burda Moden publishing plant in Offenburg. |
| 14 | In 1973, Andy Warhol visited Offenburg to create portraits of Aenne and Franz Burda. |
| 15 | In 1987, a fashion show was held in Moscow's Palace of the Unions to celebrate the launch of Burda Moden in the Soviet Union. |
| 16 | Top models like Christy Turlington and Monica Schnarre participated in the 1987 Moscow fashion show. |
| 17 | In 1988, Burda sealed an agreement with the Soviet government's newspaper Izvestia. |
| 18 | Aenne Burda transferred ownership of her publishing company to her son Hubert in 1994. |
| 19 | Burda Moden was rebranded as Burda Style and has been based in Munich since 2010. |
| 20 | Burda Style connects with its readers both in print and online. |
| 21 | Since its inception, Burda magazines have published approximately 1,500 patterns a year, totaling almost 100,000. |
| 22 | Aenne Burda was born as Anna Magdalene Lemminger in 1909. |
| 23 | Aenne Burda married Franz Burda in 1931. |
| 24 | Aenne Burda passed away in 2005 at the age of 96. |
| 25 | Burda Style's headquarters are located in Munich, Germany. |
| 26 | Burda Style's patterns cover everything from casual wear to couture fashion. |
| 27 | Aenne Burda once said, 'I wanted to create something for women to feel confident in making their own clothes.' |
| 28 | Burda Style was instrumental in democratizing fashion by making patterns accessible to everyone. |
| 29 | Burda's sewing patterns have inspired generations of home seamstresses worldwide. |
| 30 | Burda Style’s patterns include step-by-step instructions, making sewing accessible to beginners. |
| 31 | Many professional designers cite Burda patterns as an early influence on their careers. |
| 32 | The Burda Style community shares sewing projects, tips, and tricks online. |
| 33 | Burda Style has hosted international sewing competitions to celebrate creativity and craftsmanship. |
| 34 | Burda patterns are often used in fashion schools to teach sewing techniques. |
| 35 | The magazine frequently collaborates with designers to create exclusive pattern collections. |
| 36 | Burda Style patterns have been featured in runway shows as inspiration for high fashion. |
| 37 | Burda offers a 'Petite' collection, catering to shorter body types. |
| 38 | The 'Burda Easy' line simplifies patterns for quick sewing projects. |
| 39 | Burda's plus-size patterns have been celebrated for promoting body positivity. |
| 40 | Burda patterns have been adapted to fit various cultural dress styles around the world. |
| 41 | Some Burda patterns date back decades and remain popular today. |
| 42 | The Burda archive contains thousands of vintage patterns. |
| 43 | Fans of Burda Style often collect vintage issues for their historic value. |
| 44 | The Burda website features video tutorials to guide sewers through complex techniques. |
| 45 | Burda Style's online shop offers digital downloads of patterns. |
| 46 | Each Burda pattern is meticulously tested before publication. |
| 47 | The Burda Style magazine is as much about inspiration as it is instruction. |
| 48 | Burda patterns include seam allowances, making cutting fabric easier. |
| 49 | Many Burda patterns include options for customizing the fit. |
| 50 | The 'Burda Young' collection focuses on trendy, youthful designs. |
| 51 | Burda's costume patterns are popular for theater and cosplay. |
| 52 | Aenne Burda believed sewing empowered women by giving them control over their wardrobe. |
| 53 | Sewists often modify Burda patterns to create unique garments. |
| 54 | Burdas patterns have been translated into numerous languages. |
| 55 | Burda's pattern grading system ensures accurate sizing across diverse body types. |
| 56 | The Burda team includes skilled pattern makers who turn designs into sewable templates. |
| 57 | Burda Style magazine features interviews with designers and sewing experts. |
| 58 | Sewists share their Burda creations on social media with #BurdaStyle. |
| 59 | Burda Style hosts sewing challenges where participants interpret patterns in unique ways. |
| 60 | Sewing with Burda patterns is considered a rite of passage for many sewing enthusiasts. |
| 61 | Burda has hosted events where readers meet and share their creations. |
| 62 | The Burda sewing community spans across generations. |
| 63 | Aenne Burda was known for her entrepreneurial spirit and eye for design. |
| 64 | Burda patterns inspire creativity beyond clothing, including accessories and home decor. |
| 65 | Burda Style celebrates individuality through sewing. |
| 66 | Sewing Burda patterns teaches patience and attention to detail. |
| 67 | Burda's legacy continues through its patterns, inspiring sewers worldwide. |

Note entry 54 reads "Burdas patterns" (missing apostrophe) in the original. Preserved as-is above;
it is a typo in the source data, not a transcription error [CONFIRMED].

---

## 3. Covers [CONFIRMED]

Directory: `/home/x3kk3x/Desktop/Burda/assets/covers/`, 184 files.
Headers parsed directly from bytes (JPEG SOF markers, PNG IHDR) with python3 stdlib.

### Totals

| Metric | Value |
|---|---|
| Files | 184 |
| Total size | 37,661,179 B = 35.92 MiB = **37.66 MB** |
| Average | 204,680 B = **199.9 KiB** |
| Smallest | 45,214 B (`8-2011.jpg`) |
| Largest | 1,820,512 B (`12-2023.jpg`) |
| Total pixels | 117.9 MP (avg 0.64 MP per cover) |
| Format | 183 JPEG + **1 PNG** |
| JPEG encoding | 150 baseline, 33 progressive |
| JPEG components | 3 (YCbCr) for all 183 - no CMYK, no greyscale |
| Truncation (missing EOI `FFD9`) | **0** - nothing corrupt |

No cover failed to parse. No cover is missing its end-of-image marker. The set is healthy
[CONFIRMED].

### Dimensions

| Metric | Width | Height |
|---|---|---|
| Min | 375 | 469 |
| Median | 649 | 792 |
| Max | 1773 | 2048 |

142 distinct (w,h) pairs across 184 files, so these were scraped/collected individually rather
than batch-normalised [INFERRED from the dimension spread]. The single most common size is
**788x940, 20 files**. Height buckets:

| Height | Files |
|---|---|
| <= 500 | 4 |
| 501 - 700 | 37 |
| 701 - 900 | 96 |
| 901 - 1100 | 29 |
| 1101 - 1400 | 13 |
| > 1400 | 5 |

### Aspect ratio

w/h ranges from **0.7679** to **0.8657**, median cluster around 0.80 - 0.84. That is a tight band
consistent with magazine cover proportions. **No cover has a wildly different aspect ratio**
[CONFIRMED]. Extremes: `11-2021.jpg` 1773x2048 = 0.8657 (widest), one file at 0.7679 (narrowest).
A fixed `AspectRatio` of 0.81 or a `BoxFit.cover` tile will look uniform.

### The one PNG

`covers/10-2011.png`: 376,524 B, 401x484, 8-bit RGBA, chunks
`IHDR sRGB gAMA pHYs IDAT x6 IEND` [CONFIRMED]. At 401x484 it is one of the smallest covers by
pixel count yet the 10th largest by bytes, because RGBA PNG is the wrong container for a photo:
**1.94 bytes/pixel versus a 0.30 B/px median for the JPEGs** [CONFIRMED]. Converting this single
file to JPEG q85 would take it from 376 KB to roughly 55 KB [INFERRED from the median B/px], but
that changes the filename and therefore `magazines.json`. Low priority.

### Largest 12

| File | Bytes | KiB | Dimensions | Encoding |
|---|---|---|---|---|
| 12-2023.jpg | 1,820,512 | 1777.8 | 1645x2048 | baseline |
| 2-2022.jpg | 1,544,973 | 1508.8 | 1661x2048 | progressive |
| 5-2022.jpg | 1,164,416 | 1137.1 | 1655x2048 | progressive |
| 11-2021.jpg | 1,027,841 | 1003.8 | 1773x2048 | progressive |
| 8-2022.jpg | 783,494 | 765.1 | 1024x1299 | progressive |
| 7-2022.jpg | 687,911 | 671.8 | 1024x1272 | progressive |
| 12-2022.jpg | 683,883 | 667.9 | 1024x1290 | progressive |
| 9-2022.jpg | 637,132 | 622.2 | 1024x1273 | progressive |
| 2-2023.jpg | 627,402 | 612.7 | 1024x1275 | progressive |
| 2-2021.jpg | 614,878 | 600.5 | 1680x2048 | progressive |
| 1-2023.jpg | 551,387 | 538.5 | 1024x1301 | progressive |
| 11-2022.jpg | 500,165 | 488.4 | 1024x1275 | progressive |

### Smallest 12

| File | Bytes | KiB | Dimensions |
|---|---|---|---|
| 8-2011.jpg | 45,214 | 44.2 | 375x469 |
| 12-2010.jpg | 61,042 | 59.6 | 377x472 |
| 11-2011.jpg | 63,055 | 61.6 | 518x625 |
| 2-2011.jpg | 66,290 | 64.7 | 476x607 |
| 10-2013.jpg | 67,250 | 65.7 | 492x606 |
| 11-2013.jpg | 71,428 | 69.8 | 486x604 |
| 12-2012.jpg | 71,473 | 69.8 | 435x566 |
| 2-2012.jpg | 72,366 | 70.7 | 482x600 |
| 1-2012.jpg | 72,535 | 70.8 | 485x605 |
| 3-2013.jpg | 74,914 | 73.2 | 444x562 |
| 3-2011.jpg | 75,384 | 73.6 | 482x601 |
| 6-2015.jpg | 75,724 | 73.9 | 500x607 |

### Weight by year (where the bloat lives)

| Year | Files | Total B | Total KiB | Avg KiB |
|---|---|---|---|---|
| 2010 | 12 | 2,052,191 | 2004.1 | 167.0 |
| 2011 | 12 | 1,391,718 | 1359.1 | 113.3 |
| 2012 | 12 | 1,310,009 | 1279.3 | 106.6 |
| 2013 | 12 | 1,346,659 | 1315.1 | 109.6 |
| 2014 | 12 | 1,679,358 | 1640.0 | 136.7 |
| 2015 | 12 | 1,460,151 | 1425.9 | 118.8 |
| 2016 | 12 | 1,954,775 | 1909.0 | 159.1 |
| 2017 | 12 | 1,981,595 | 1935.2 | 161.3 |
| 2018 | 12 | 1,903,457 | 1858.8 | 154.9 |
| 2019 | 12 | 1,948,765 | 1903.1 | 158.6 |
| 2020 | 12 | 2,088,135 | 2039.2 | 169.9 |
| 2021 | 12 | 3,141,117 | 3067.5 | 255.6 |
| **2022** | 12 | **7,501,377** | 7325.6 | **610.5** |
| **2023** | 12 | **5,385,556** | 5259.3 | **438.3** |
| 2024 | 12 | 1,899,749 | 1855.2 | 154.6 |
| 2025 | 4 | 616,567 | 602.1 | 150.5 |

2022 and 2023 alone are **12.89 MB, 34% of all covers** [CONFIRMED]. Those two years were sourced
at 1024-2048 px height while the rest sit around 600-800 px. That is the single biggest,
cheapest win.

---

## 4. Icons and background [CONFIRMED]

### Icons

Directory: `/home/x3kk3x/Desktop/Burda/assets/icon/`, 42 PNG files.
Total **1,219,591 B = 1191.0 KiB = 1.22 MB**, average 28.4 KiB.
Every file has a valid IHDR and an IEND chunk - none corrupt [CONFIRMED].

| File | Bytes | Dimensions | Depth | Colour type | Named in libapp? |
|---|---|---|---|---|---|
| after.png | 28,360 | 512x512 | 8 | RGBA | yes (L10613) |
| arrow.png | 11,066 | 512x512 | 8 | RGBA | yes (L11980) |
| bag.png | 20,248 | 512x512 | 8 | RGBA | **no** |
| before.png | 40,936 | 512x512 | 8 | RGBA | **no** |
| books.png | 12,349 | 512x512 | 8 | RGBA | **no** |
| bulb.png | 51,111 | 512x512 | 8 | RGBA | **no** |
| button.png | 26,967 | 512x512 | 8 | RGBA | yes (L15462) |
| calendar.png | 11,948 | 512x512 | 8 | RGBA | yes (L13747) |
| coffee-cup.png | 92,987 | 512x512 | 8 | RGBA | yes (L8011) |
| couch.png | 8,055 | 512x512 | 8 | RGBA | **no** |
| diamond.png | 31,321 | 512x512 | 8 | RGBA | **no** |
| document.png | 8,190 | 512x512 | 8 | RGBA | yes (L10896) |
| doll.png | 59,560 | 512x512 | 8 | RGBA | yes (L3612) |
| dress.png | 35,519 | 512x512 | 8 | RGBA | yes (L4885) |
| dummy.png | 39,505 | 512x512 | 8 | RGBA | yes (L14382) |
| eyeliner.png | 13,714 | 512x512 | 8 | RGBA | yes (L15841) |
| fancy.png | 5,614 | 512x512 | 8 | **palette** | **no** |
| fire.png | 36,459 | 512x512 | 8 | RGBA | yes (L8327) |
| flame.png | 46,314 | 512x512 | 8 | RGBA | yes (L9423) |
| hat.png | 3,843 | **279x279** | 8 | **palette** | **no** |
| home.png | 17,741 | 512x512 | 8 | RGBA | yes (L10440) |
| icon.png | 79,051 | 512x512 | 8 | RGBA | yes (L15535) |
| knitting.png | 39,094 | 512x512 | 8 | RGBA | **no** |
| lipstick.png | 30,064 | 512x512 | 8 | RGBA | yes (L7136) |
| machine.png | 12,465 | 512x512 | 8 | RGBA | yes (L5907) |
| magazine.png | 11,352 | 512x512 | 8 | RGBA | yes (L13692) |
| magazines.png | 13,444 | 512x512 | 8 | RGBA | **no** |
| mannequin.png | 21,357 | **128x128** | 8 | RGBA | **no** |
| mirror.png | 20,475 | 512x512 | 8 | RGBA | yes (L7516) |
| needle.png | 26,133 | 512x512 | 8 | RGBA | **no** |
| question.png | 4,604 | **100x100** | 8 | RGBA | yes (L13507) |
| searching.png | 13,054 | 512x512 | 8 | RGBA | yes (L12091) |
| settings.png | 62,903 | 512x512 | 8 | RGBA | yes (L8508) |
| sewing-machine.png | 30,502 | 512x512 | 8 | RGBA | yes (L2423) |
| star.png | 30,458 | 512x512 | 8 | RGBA | **no** |
| tape.png | 16,873 | 512x512 | 8 | RGBA | **no** |
| thread.png | 21,385 | 512x512 | 8 | RGBA | **no** |
| tracking-app.png | 46,265 | 512x512 | 8 | RGBA | yes (L5850) |
| tree.png | 42,575 | 512x512 | 8 | RGBA | **no** |
| trophy.png | 35,671 | 512x512 | 8 | RGBA | **no** |
| yarn.png | 44,810 | 512x512 | 8 | RGBA | yes (L5938) |
| yes.png | 15,249 | 512x512 | 8 | RGBA | yes (L8208) |

Dimension histogram: 512x512 x 39, 279x279 x 1 (`hat.png`), 128x128 x 1 (`mannequin.png`),
100x100 x 1 (`question.png`) [CONFIRMED]. The three odd sizes are the ones to watch if a rebuild
renders icons at a fixed box: `question.png` at 100x100 will look soft if drawn at 48 logical px
on a 3x screen.

`fancy.png` and `hat.png` are palette PNGs, everything else is RGBA [CONFIRMED].

**25 of 42 icons appear as string literals; 17 do not.** The 17 unreferenced:
`bag, before, books, bulb, couch, diamond, fancy, hat, knitting, magazines, mannequin, needle,
star, tape, thread, tree, trophy` (all `.png`) = **476,236 B / 465 KiB dead** [CONFIRMED]. I
checked for dynamic path construction and found none: there is no `assets/icon/` prefix literal
and no bare filename literal for any of the 17 (the two near-hits, `magazines` at L8797 and
`before` at L16602, are the SQL table name and an unrelated word) [CONFIRMED]. So these are
genuinely unused leftovers, not runtime-composed paths.

Two error strings confirm icons are loaded with individual error handling:
- `libapp_strings.txt:5414` = `Error loading coffee-cup.png in modal: `
- `libapp_strings.txt:13201` = `Error loading searching.png: `
[CONFIRMED] - so `coffee-cup.png` is shown in a modal/dialog and `searching.png` in an empty
state [INFERRED from the wording].

### Background image

`/home/x3kk3x/Desktop/Burda/assets/images/background.png`
**906,302 B (885 KiB), 1500x1500, 8-bit RGBA** [CONFIRMED].

**It is not referenced anywhere.** `assets/images/background.png` does not appear as a string in
`lib/arm64-v8a/libapp.so` or `lib/x86_64/libapp.so`, and no `images/` path literal exists at all
(the only near matches are Flutter framework symbols and `/magazine_images/`) [CONFIRMED by
`strings | grep` on both .so files]. `lib/widgets/floating_background.dart` exists
(`libapp_strings.txt:11925`) with `FloatingBackground` / `_FloatingBackgroundState`
(L16072, L12618, L12667), so the floating background is drawn programmatically, not from this PNG
[INFERRED]. `background.png` is 885 KiB of dead weight, or an asset whose code path was deleted
before the final build.

### Unrelated but adjacent finding

`libapp_strings.txt:4163` = `/magazine_images/` and `:8158` = `/magazine_images`, next to
`getApplicationDocumentsDirectory` (L7869) and the pigeon channel
`...PathProviderApi.getApplicationDocumentsPath` (L3254). User-added cover photos are stored in
a `magazine_images` subdirectory of the app documents directory, **not** in bundled assets
[CONFIRMED]. That is runtime data, outside this slice, but it explains why `image` can hold a
non-asset path at runtime and why `placeholder.jpg` was wanted as a fallback.

---

## 5. Fonts [CONFIRMED]

Directory: `/home/x3kk3x/Desktop/Burda/assets/fonts/`, 19 files, all valid TrueType
(`sfnt` version `0x00010000`) [CONFIRMED].
Total **2,436,744 B = 2379.6 KiB = 2.44 MB**.

| File | Bytes | KiB | Declared family | Weight/style |
|---|---|---|---|---|
| AlfaSlabOne-Regular.ttf | 92,956 | 90.8 | AlfaSlabOne | default |
| Anton-Regular.ttf | 161,588 | 157.8 | Anton | default |
| BebasNeue-Regular.ttf | 57,676 | 56.3 | BebasNeue | default |
| BungeeTint-Regular.ttf | 217,004 | 211.9 | BungeeTint | default |
| FleurDeLeah.ttf | 230,668 | 225.3 | FleurDeLeah | default |
| Lato-Thin.ttf | 69,976 | 68.3 | Lato | 100 |
| Lato-ThinItalic.ttf | 48,864 | 47.7 | Lato | 100 italic |
| Lato-Light.ttf | 77,208 | 75.4 | Lato | 300 |
| Lato-LightItalic.ttf | 49,080 | 47.9 | Lato | 300 italic |
| Lato-Regular.ttf | 75,152 | 73.4 | Lato | 400 |
| Lato-Italic.ttf | 75,792 | 74.0 | Lato | 400 italic |
| Lato-Bold.ttf | 73,332 | 71.6 | Lato | 700 |
| Lato-BoldItalic.ttf | 77,732 | 75.9 | Lato | 700 italic |
| Lato-Black.ttf | 69,500 | 67.9 | Lato | 900 |
| Lato-BlackItalic.ttf | 72,000 | 70.3 | Lato | 900 italic |
| LilitaOne-Regular.ttf | 26,828 | 26.2 | LilitaOne | default |
| Roboto.ttf | 468,308 | 457.3 | Roboto | default |
| ZillaSlabHighlight-Bold.ttf | 245,180 | 239.4 | **none** | - |
| ZillaSlabHighlight-Regular.ttf | 247,900 | 242.1 | **none** | - |

### pubspec vs original FontManifest

The original `FontManifest.json` from the APK lists **9 families**: `MaterialIcons` (from
`uses-material-design: true`) plus the 8 app families. The 8 app families and all 18 asset paths
and every weight/style pair match the new `pubspec.yaml` **exactly**, entry for entry
[CONFIRMED - byte-compared family names, asset paths, weights, and `style: italic` flags].

| Check | Result |
|---|---|
| Families declared in pubspec | 8 |
| Families in original FontManifest (excl. MaterialIcons) | 8 - identical set |
| Font asset paths referenced by a family | 17 |
| Referenced font files that exist on disk | **17 / 17** |
| Font files present but in no family | **2** (both ZillaSlabHighlight) |

The two `ZillaSlabHighlight-*.ttf` (493,080 B / 481.5 KiB combined) ship because
`assets/fonts/` is declared as a whole directory under `assets:`, but they have no `family` entry,
so **no widget can reference them by family name** [CONFIRMED]. Same situation as the original
APK, so this is faithful, not a regression. 481 KiB of unusable font data. If a rebuild wants
them, add a `ZillaSlabHighlight` family; if not, they can go.

`Roboto.ttf` at 457 KiB is the single largest font, and Flutter already bundles Roboto as its
default on Android, so declaring a custom `Roboto` family is likely redundant [INFERRED - the
file is a real TTF and is declared, so it does work, but the platform default would serve].

---

## 6. AssetManifest.json vs pubspec declarations [CONFIRMED]

Original: `/home/x3kk3x/Desktop/Burda/recovery/apk/assets/flutter_assets/AssetManifest.json`,
14,101 bytes, **248 entries**. Every entry's variant list is exactly `[key]` - no resolution
variants (`2.0x`, `3.0x`), no `--asset-manifest` trickery [CONFIRMED].

| Directory | Manifest entries | Files on disk |
|---|---|---|
| `assets/` (root: the 2 JSON) | 2 | 2 |
| `assets/covers/` | 184 | 184 |
| `assets/fonts/` | 19 | 19 |
| `assets/icon/` | 42 | 42 |
| `assets/images/` | 1 | 1 |
| **Total** | **248** | **248** |

- **In manifest, missing on disk: 0** [CONFIRMED]
- **On disk, not in manifest: 0** [CONFIRMED]

The new `pubspec.yaml` declares:

```yaml
assets:
  - assets/magazines.json
  - assets/quotes.json
  - assets/covers/
  - assets/icon/
  - assets/images/
  - assets/fonts/
```

Those six declarations cover exactly the five directories above (the two JSON named explicitly,
plus four directory declarations). Nothing original is left undeclared and nothing extra is
declared [CONFIRMED]. The `assets/fonts/` directory declaration is what also bundles the two
unreferenced ZillaSlabHighlight files, matching the original's behaviour.

Also present in the original `flutter_assets/` but **not** app assets (Flutter tooling generates
them, do not hand-create):
`AssetManifest.bin` (15,838 B), `AssetManifest.json` (14,101 B), `FontManifest.json` (1,288 B),
`NativeAssetsManifest.json` (45 B), `NOTICES.Z` (92,815 B), `fonts/MaterialIcons-Regular.otf`,
`shaders/` [CONFIRMED].

### Dangling code references (asset bugs carried over from the original)

29 distinct `assets/...` string literals exist in `libapp.so`. Two do not resolve:

| Line | Literal | Status |
|---|---|---|
| 14855 | `assets/covers/placeholder.jpg` | **Not in the original manifest and not on disk. Broken in the shipped app too.** |
| 12416 | `assets/` | A bare prefix string, not a path. Harmless. |

So whichever screen falls back to `placeholder.jpg` when a cover fails to load has been silently
throwing in the original app since it was built [CONFIRMED]. Either create a
`assets/covers/placeholder.jpg` in the rebuild (and declare it - the directory declaration already
would) or change the fallback to an existing icon such as `assets/icon/magazine.png`. This is the
one actionable asset defect found.

The other 27 literals are the 25 icons and the 2 JSON files, all present. `assets/magazines.json`
is at L3398 and `assets/quotes.json` at L9171 [CONFIRMED].

### Integrity re-verification

Independently re-checked md5 of 8 representative files against the unzipped APK:
`covers/1-2010.jpg`, `covers/10-2011.png`, `covers/12-2023.jpg`, `covers/4-2025.jpg`,
`magazines.json`, `quotes.json`, `images/background.png`, `icon/icon.png` - **all 8 identical**
[CONFIRMED]. Consistent with the earlier full-set verification.

---

## 7. Compression data for a later decision (no files changed)

### Current state

| Group | Size | Share of assets |
|---|---|---|
| Covers | 37.66 MB | 89.1% |
| Fonts | 2.44 MB | 5.8% |
| Icons | 1.22 MB | 2.9% |
| Background | 0.91 MB | 2.1% |
| JSON | 0.03 MB | 0.1% |
| **Assets total** | **42.26 MB** | 100% |
| Release APK total | 74.18 MB | - |

Assets are **57% of the whole APK** [CONFIRMED: 42,255,495 uncompressed asset bytes out of
74,176,282 APK bytes].

**The zip cannot help.** In the APK, the 248 asset entries take 42,255,495 B uncompressed and
40,960,192 B stored, a **96.9% ratio** [CONFIRMED via `unzip -lv`]. JPEG and PNG are already
entropy-coded, so deflate recovers ~3%. Any real saving has to come from re-encoding the images
themselves.

### Baseline metrics for modelling

- Median existing quality is **0.2999 bytes/pixel**; mean 0.3180; range 0.1364 (most aggressive
  existing JPEG) to 1.9400 (the RGBA PNG) [CONFIRMED].
- A JPEG at quality ~85 lands near **0.22 B/px**; quality ~75 near **0.18 B/px**; quality ~92
  near **0.28 B/px** [INFERRED from the observed distribution of this exact image set, since the
  0.1364 floor already exists in-set at acceptable quality].

### Resize simulation

Cap the longer side (height), preserve aspect, re-encode at the given bytes/pixel, and never let
a file grow. "files ch" = how many of the 184 files actually shrink.

| Cap height | B/px (approx q) | New covers total | Saved | Saved % | Files changed |
|---|---|---|---|---|---|
| 1200 | 0.18 (q75) | 18.70 MB | 18.96 MB | 50.3% | 175 |
| 1200 | 0.22 (q85) | 22.41 MB | 15.25 MB | 40.5% | 161 |
| 1200 | 0.28 (q92) | 26.92 MB | 10.74 MB | 28.5% | 115 |
| 1000 | 0.18 | 17.57 MB | 20.09 MB | 53.3% | 177 |
| 1000 | 0.22 | 21.16 MB | 16.50 MB | 43.8% | 165 |
| 1000 | 0.28 | 25.60 MB | 12.06 MB | 32.0% | 118 |
| **900** | **0.22** | **20.22 MB** | **17.45 MB** | **46.3%** | 170 |
| 900 | 0.18 | 16.69 MB | 20.97 MB | 55.7% | 183 |
| 900 | 0.28 | 24.68 MB | 12.98 MB | 34.5% | 122 |
| 800 | 0.22 | 18.59 MB | 19.08 MB | 50.7% | 179 |
| 800 | 0.18 | 15.24 MB | 22.42 MB | 59.5% | 184 |
| 700 | 0.22 | 15.06 MB | 22.60 MB | 60.0% | 183 |
| 600 | 0.22 | 11.68 MB | 25.99 MB | 69.0% | 183 |

### The cheap 80/20

| Scope | Size | Share of covers |
|---|---|---|
| Top 5 largest | 6.34 MB | 16.8% |
| Top 10 largest | 9.59 MB | 25.5% |
| Top 20 largest | 13.52 MB | 35.9% |
| Top 40 largest | 18.10 MB | 48.1% |
| Years 2022 + 2023 only | 12.89 MB | 34.2% |

**Normalising only 2022 and 2023 to a 900 px cap at q85 takes ~12.89 MB down to ~2.0 MB, saving
~10.9 MB (29% of all covers) while touching 24 of 184 files** [INFERRED from their dimensions and
the 0.22 B/px model]. That plus the single RGBA PNG (376 KB to ~55 KB) is the least invasive
option.

### Recommendation as data, not a decision

- The median cover is 649x792. On a phone a cover tile is typically 150-200 logical px wide and a
  detail view 360-400 logical px wide, so at 3x DPI **~1200 px of width is the most any screen can
  use, and ~900 px height is already generous** [INFERRED from typical Flutter layout, not
  measured from this app's widget tree].
- A **900 px height cap at q85** is the balanced option: **37.66 MB to 20.22 MB, saving 17.45 MB
  (46%)**, with no visible loss on device since only 47 of 184 files exceed 900 px height today
  and the other 137 only get re-encoded if that is smaller.
- Doing nothing is also defensible: 42 MB of assets in a personal sideloaded app costs nothing but
  install size, and the originals are the only surviving copies of these covers.
- If anything is re-encoded, **keep the originals** in a separate untracked folder first. Once
  re-encoded there is no way back, and the covers are irreplaceable scraped data.
- Deleting `background.png` (885 KiB) and the 17 unused icons (465 KiB) and the 2 unusable
  ZillaSlabHighlight fonts (481 KiB) is a **1.79 MB** saving at zero visual risk, but it diverges
  from the original APK. Faithfulness versus size is a call for x3kk, not a technical question.

---

## Appendix: full-fidelity checklist for the rebuild

1. Copy `magazines.json` and `quotes.json` byte-for-byte. Both lack a trailing newline. `quotes.json`
   contains one U+2019; do not normalise it, and do not add a BOM.
2. Read `image` from each magazine entry verbatim. `10/2011` is `.png`.
3. Seed `isOwned` from JSON only on first run. All 184 seed values are false.
4. `quotes.json` has a single `type` value, `"fact"`. Keep the field, branch on nothing.
5. Either add `assets/covers/placeholder.jpg` or change the fallback - the original reference is
   broken.
6. Keep all 6 asset declarations and all 8 font families with the exact weights in the table in
   section 5; they match the original FontManifest exactly.
7. `background.png` and 17 icons are unreferenced. Keep them for fidelity or drop them for size,
   but know they are dead.
8. User-added cover photos live in `<app documents>/magazine_images/`, not in assets.
