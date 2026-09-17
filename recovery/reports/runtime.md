# Burda Style - Live Runtime Screen Tour (original release APK)

Status: IN PROGRESS - written incrementally.

## Environment [CONFIRMED]
- Emulator AVD `rmind`, x86_64, API 36, 1080x2340, density 440.
- Installed `/home/x3kk3x/Desktop/Burda/app-release.apk` with `adb install -r` -> Success. Package `com.example.burda`, launch activity `com.example.burda.MainActivity`.
- Screenshots + dumps: `/home/x3kk3x/Desktop/Burda/recovery/screens/`

### Tooling note [CONFIRMED]
`adb shell uiautomator dump` returns an EMPTY hierarchy (46 bytes) for this app - the Flutter release build does not publish a semantics tree unless a real a11y service attaches. One early dump returned a stale tree left over from a `monkey`-injected random tap. Therefore all texts/bounds below come from screenshots read visually; coordinates are original-image pixels (1080x2340).
Do NOT launch with `adb shell monkey -p ... 1`: the trailing `1` injects one random event that taps the UI. Use `adb shell am start -n com.example.burda/com.example.burda.MainActivity`.

## Measured colors - light theme [CONFIRMED, sampled from 01-first-launch-home.png]
| Role | Hex | Material name |
|---|---|---|
| Scaffold background | `#FFFFFF` | white |
| Card / info block / stats card / progress track | `#F8BBD0` | Pink 100 |
| Bottom navigation bar | `#E91E63` | Pink 500 (`Colors.pink`) |
| All body + label text | `#B71C1C` | Red 900 |
| Progress bar percentage text | `#FFFFFF` | white |
| Title "Burda Style" glyph fill | ~`#E7B2B2` rose, vertical gradient lighter at top-left | - |
| Selected nav item halo | `#F8BBD0` circle on `#E91E63` | Pink 100 |

## Screen 01 - Home (first launch) - `01-first-launch-home.png`, `02-home-b.png`, `tmp-check.png`
No onboarding, no permission prompt, no splash text on first launch. Straight to Home.

Top to bottom:
1. Floating animated emoji background (widgets/floating_background.dart) - drifting emoji images: thread spool, sewing machine, pink dress, pin cushion, ball of yarn, coffee cup with heart, map-on-phone, magnifying glass, blue X button. They move between frames (compare `01`, `02`, `tmp-check`), some overlap the title and the stats card. [CONFIRMED]
2. Title "Burda Style" in a large script font (FleurDeLeah) with a rose vertical gradient. [CONFIRMED]
3. Rotating quote, italic, `#B71C1C`, wrapped in straight double quotes, centred. Observed values across three frames: `"Aenne Burda passed away in 2005 at the age of 96."`, `"Aenne Burda once said, 'I wanted to create something for women to feel confident in making their own clothes.'"`, `"Burda's sewing patterns have inspired generations of home seamstresses worldwide."`, `"Sewing with Burda patterns is considered a rite of passage for many sewing enthusiasts."` The quote changes on its own every few seconds. [CONFIRMED]
4. Stats card, `#F8BBD0`, rounded ~16px, with a 3D lipstick image on the right:
   - newspaper emoji `Total Magazines: 184`
   - calendar emoji `Latest Addition: N/A`
   - seedling emoji `Oldest Issue: 2010`
   - alarm/fire emoji `Days Visited: 1`
   [CONFIRMED] `Days Visited` is a persisted counter (shared_preferences) - it read 1 on a fresh install.
5. Horizontal progress bar, full width, pink track, white centred `0%` text. [CONFIRMED]
6. 2x3 grid of info blocks (widgets/info_blocks.dart), pink cards, label above value:
   `OWNED 0` | `MISSING 184` | `NOTES 0`
   `RANK Threadling` | `VAULT 0` | `WEAR N/A`
   [CONFIRMED] RANK is a gamified title; `Threadling` is the level at 0 owned.
7. Bottom navigation bar: pink `#E91E63` pill, 5 items, centre item raised in a pale circle.
   Approximate tap centres: home `(150,2237)`, second icon `(310,2237)`, centre dress `(538,2229)`, fourth icon `(770,2237)`, gear `(925,2237)`.

## Screen 02 - Missing-by-year bottom sheet (nav item 2) - `03-nav2.png`, `04-nav2-scroll.png`, `05-nav2-bottom.png`
Reached by tapping nav item 2 (the "stacked lines" icon at `(310,2237)`). It is a **modal bottom sheet over the Home screen**, not a pushed route: Home stays visible and dimmed behind it, and the bottom nav is covered. [CONFIRMED]
- Sheet occupies roughly the lower 58% of the screen, top corners rounded ~32px.
- Sheet background is a vertical gradient: `#B91E1F` (dark red) at the top -> `#EE608E` (pink) at the bottom. [CONFIRMED, sampled]
- A short pale-pink drag handle sits centred at the top; no title text at all.
- Scrollable list of white cards (`#FFFFFF`), one per year, ~170px tall with ~24px gaps and a soft drop shadow. Each row, left to right:
  1. large broken-heart glyph (red)
  2. the year, large, `#B71C1C`-ish red
  3. small filled heart + owned count
  4. small broken heart + missing count
  5. pink `share` icon (Material `share`) on the right
- Years present: 2010 through 2025. All 2010-2024 rows read `12` missing; **2025 reads `4`** (the asset set stops at 4/2025). [CONFIRMED]
- Tapping a row pushes the year listing screen (Screen 03). Tapping the row anywhere but the share icon works.

## Screen 03 - Year listing / "Browse Issues" - `06-missing-2025.png` (carousel), `07-year-grid.png` (grid)
App bar: `#E91E63`, white back arrow, centred white title = the year (`2025`), and one action icon top-right that **toggles carousel <-> grid**: shows a `grid_view` icon while in carousel mode and a `view_carousel` icon while in grid mode. Action centre `(1010,143)`. [CONFIRMED]

Body top to bottom:
1. `Browse Issues` - very large, heavy slab display face, `#B71C1C`. [CONFIRMED]
2. Two-line subtitle, `#CC6060`: `Tap a year, meet its issues` / `twelve chances to judge a cover by it` [CONFIRMED - note there is no trailing period and the second line is a deliberate half-sentence]
3. **Carousel mode**: one large cover centred with neighbours peeking in at both edges (carousel_slider), swipeable.
   **Grid mode**: 2-column grid of covers.
4. Every cover card carries a translucent grey bar across its lower third, and inside it:
   - left: heart. Broken white heart = not owned. Solid heart `#F44336` = owned. Tapping it toggles owned. [CONFIRMED]
   - centre: the issue title, e.g. `1/2025`, white.
   - right: white `delete`/trash icon.
   - and, **only once the issue is owned**, an extra icon between the title and the trash that opens the condition dialog. That icon is the app's own `assets/icon/document.png` (a red page with an `x_x` face): rendered as a white silhouette while the issue has no condition score, and in its natural red/navy colours once a score is saved. [CONFIRMED - compare `08-own-toggle-a.png` white page vs `12-condition-saved.png` coloured page; asset identified by reading `assets/icon/document.png`]
5. Bottom navigation bar stays visible on this screen.

Toggling owned produced **no confetti, no snackbar and no dialog** here - it just swaps the heart. [CONFIRMED, `08`/`09` taken 1s and 3s after the tap]

## Dialog - "Evaluate Condition" - `10-owned-extra-icon.png`, `11-condition-slider-max.png`, `12-condition-saved.png`
Opened from the condition icon on an owned cover card.
- A rounded (~28px) dialog whose background is **semi-transparent pink** - the magazine covers behind it show straight through the panel, not just through the barrier. Sampled body pixels land on `#E12A69`..`#D82162` over the artwork. [CONFIRMED] This reads as an accident (`Colors.pink.withOpacity(...)` on the dialog surface).
- Title, white, centred: `Evaluate Condition for 1/2025` (title interpolates the issue title).
- Subtitle, white, centred: `Rate the condition from 1 (Worn) to 10 (Mint)`
- A `Slider`, full dialog width, pale-pink active track and thumb. **No value label, no divisions, no tick marks** - you cannot see which number you picked while dragging. [CONFIRMED]
- One button, `SAVE`, uppercase, `#F8BBD0` fill with `#E91E63` label, centred.
- Tapping outside dismisses. Tapping `SAVE` closes and shows a snackbar.
- Snackbar: `Condition set to 10.0` - note the **`.0` decimal leaks the double** into user-facing copy. Default black `#000000` full-width rectangular snackbar, white text, left-aligned, and it sits *under* the bottom nav bar. [CONFIRMED]
- The initial thumb position on first open was ~42% of the track (a default of about 5). [INFERRED from `10-owned-extra-icon.png`]

## Screen 04 - Issue detail (per-issue photo gallery) - `13-issue-detail.png`, `16-issue-detail-with-image.png`
Reached by tapping the cover artwork (not the overlay bar) on Screen 03.
- App bar `#E91E63`, back arrow, centred title = issue title (`1/2025`). No actions.
- Empty state: centred `No images uploaded yet.` in `#E91E63`. [CONFIRMED]
- Bottom of the body: a single `Upload Image` button, `#F8BBD0` fill, `#E91E63` bold label, rounded ~12px, centred, sitting just above the bottom nav. [CONFIRMED]
- There is **no condition control, no date-added display and no notes field on this screen** - it is purely a photo gallery for that issue. [CONFIRMED]
- `Upload Image` opens the **Android system photo picker directly** - no "camera or gallery?" choice sheet. The picker header reads `Burda Style will only have access to the photos you select`, which confirms the app label is `Burda Style`. Single-select. [CONFIRMED, `14-upload-image.png`, `15-picker-with-photos.png`]
- After picking: snackbar `Image uploaded successfully!` and the photo appears as the first cell of a 2-column grid, top-left, with the rest of the grid empty. [CONFIRMED]
- Tapping a thumbnail opens a borderless full-width `Dialog` showing the image large over a dimmed backdrop. Dismissed by tapping outside or by the back button. [CONFIRMED, `17-image-tap.png`]
- Swiping left/right inside that overlay does nothing - it is a single-image dialog, not a pageable viewer. [CONFIRMED, `18-image-swipe.png`]
- **Long-pressing a thumbnail just opens the same viewer** - there is no delete/remove affordance for an uploaded photo anywhere on this screen. [CONFIRMED, `19-image-longpress.png`]

## Navigation map
(to be filled)

## Dialogs and snackbars
(to be filled)

## Bugs and glitches
- Floating background emoji draw OVER the title text and over the info blocks (e.g. the blue `?` bubble sits on top of `VAULT` in `01-first-launch-home.png`, the coffee cup overlaps the grid). Cosmetic but looks like a z-order accident. [CONFIRMED]
- `Latest Addition` reads `N/A` with nothing owned, and reads a month/year once something is owned.
(more to be filled)
