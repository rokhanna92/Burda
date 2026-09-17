# Burda Style APK recovery - platform, dependencies, Android config

Slice: build platform, dependencies, Android configuration.

Evidence base:
- APK `/home/x3kk3x/Desktop/Burda/app-release.apk` (74,176,282 bytes, 668 zip entries, 115,267,915 bytes uncompressed)
- Unzipped at `/home/x3kk3x/Desktop/Burda/recovery/apk/`
- AOT strings at `/home/x3kk3x/Desktop/Burda/recovery/libapp_strings.txt` - verified to be exactly
  `strings -n 4 apk/lib/arm64-v8a/libapp.so` (28406 lines both ways), so line numbers below are
  citable and the file is complete for that ABI. Spot checks were repeated against
  `apk/lib/x86_64/libapp.so` and agreed.
- Decompressed `apk/assets/flutter_assets/NOTICES.Z` (gzip, magic `1f8b0800`, 1,829,553 bytes
  inflated, 1067 license blocks)
- `aapt2`/`dexdump` from `~/Android/Sdk/build-tools/36.0.0/`

Confidence tags: **[CONFIRMED]** direct evidence with citation, **[INFERRED]** strong inference with
the reason stated, **[GUESS]** speculation.

---

## 1. SDK and toolchain versions

| Item | Value | Confidence |
| --- | --- | --- |
| Dart SDK | **3.7.2 (stable)**, built Tue Mar 11 04:27:50 2025 -0700 | [CONFIRMED] |
| Flutter SDK | **3.29.2** (or 3.29.3) | [INFERRED] |
| Gradle | **8.10.2** | [CONFIRMED] |
| Android Gradle Plugin | **8.7.0** | [CONFIRMED] |
| Kotlin Android Gradle plugin | **1.8.22** | [CONFIRMED] |
| Java source/target compatibility | **11** | [CONFIRMED] |
| kotlinx-coroutines (pulled in) | 1.7.3 | [CONFIRMED] |
| compileSdk / targetSdk / minSdk | 35 / 35 / 21 | [CONFIRMED] |
| NDK version | not recoverable from the APK | - |

Evidence:
- Dart: the only `(stable)` version string in `apk/lib/arm64-v8a/libflutter.so` is
  `3.7.2 (stable) (Tue Mar 11 04:27:50 2025 -0700) on "android_arm64"`.
- Flutter version: Dart 3.7.2 shipped in the Flutter 3.29.2 and 3.29.3 stable releases. The engine
  build date of 11 March 2025 lines up with Flutter 3.29.2 (released 12 March 2025) rather than
  3.29.3 (April 2025), so **3.29.2 is the best single answer**. [INFERRED]
- Two 40-hex candidate engine revisions are present in `libflutter.so`:
  `cf56914b326edb0ccb123ffdc60f00060bd513fa` and `e7b8d078851fd505475fe74359e31a421e6968ea`.
  Neither is labelled, so I am not asserting which is the engine hash. [CONFIRMED that the strings
  exist; their role is unverified]
- Gradle / Kotlin / Java: `apk/kotlin-tooling-metadata.json`
  (`buildSystemVersion: 8.10.2`, `buildPluginVersion: 1.8.22`, `sourceCompatibility/targetCompatibility: 11`).
  Kotlin 1.8.22 is exactly the Flutter Android template default for that era, so the
  `settings.gradle(.kts)` Kotlin version was almost certainly left untouched. [INFERRED]
- AGP: `apk/META-INF/com/android/build/gradle/app-metadata.properties` contains
  `androidGradlePluginVersion=8.7.0`.
- SDK levels and package id: `aapt2 dump badging` reports
  `package: name='com.example.burda' versionCode='1' versionName='1.0.0'`,
  `minSdkVersion:'21'`, `targetSdkVersion:'35'`, `compileSdkVersion='35'`.

### Build flags used

- **Release mode, fat APK, no ABI split.** `lib/` holds `libapp.so` + `libflutter.so` for
  `arm64-v8a`, `armeabi-v7a` and `x86_64`. `lib/x86/` contains only third-party AAR natives
  (`libbarhopper_v3.so`, `libdatastore_shared_counter.so`, `libimage_processing_util_jni.so`) and no
  Flutter libs, which is the signature of the default
  `--target-platform android-arm,android-arm64,android-x64` set. [CONFIRMED]
- **Dart obfuscation was NOT used.** Library URIs, class names, field names and private-name
  library hashes are all readable in `libapp.so`. [CONFIRMED]
- **Icon tree shaking was on** (the Flutter default). `assets/flutter_assets/fonts/MaterialIcons-Regular.otf`
  is only 3,480 bytes and its `cmap` carries exactly 24 codepoints. [CONFIRMED]
- **R8 minification and resource shrinking were on** (also the Flutter release default). A single
  `classes.dex` with renamed types (`LW1/g;`, `Lh2/e;`, `Lu2/a;`, `Lc2/t;`) and shortened resource
  file names (`res/9w.png`, `res/Zn.xml`) in `resources.arsc`. No custom `proguard-rules.pro`
  behaviour is detectable. [CONFIRMED that R8 + shrinker ran; INFERRED that no custom rules existed]
- `android:extractNativeLibs="true"` on `<application>` - the Flutter embedding default, not a
  project-level choice. [CONFIRMED present, INFERRED as default]
- No `io.flutter.embedding.android.SplashScreenDrawable` meta-data, no `EnableImpeller` meta-data,
  no `flutter_native_splash` artifacts. Renderer selection was left at the default. [CONFIRMED]

### Signing - IMPORTANT, read this

`keytool -printcert -jarfile app-release.apk`:

```
Owner:  C=US, O=Android, CN=Android Debug
Issuer: C=US, O=Android, CN=Android Debug
Valid from: Sun Mar 02 18:51:19 CET 2025 until: Tue Feb 23 18:51:19 CET 2055
SHA1:   9E:89:FA:61:18:67:B7:73:2B:78:7C:23:67:BC:9B:C5:A6:D1:6C:B6
SHA256: 21:91:C6:AF:2E:12:34:AF:BE:8B:78:45:ED:B6:DF:1C:8F:75:80:76:47:D5:10:30:02:43:B1:BF:82:19:92:41
```

- [CONFIRMED] The "release" APK is signed with the **Android debug keystore**, i.e. the template's
  `buildTypes { release { signingConfig = signingConfigs.debug } }` was never replaced. So
  `android/app/build.gradle(.kts)` was the stock Flutter template. [INFERRED from that]
- [CONFIRMED] The debug keystore currently on this machine is **a different key**:
  `~/.android/debug.keystore` was created Wed Sep 16 2026 and has
  SHA1 `4F:33:F4:9B:EA:CE:03:80:F4:E4:D8:AE:E1:40:95:2D:31:F5:30:2C`. The original signing key is
  gone along with the source.
- **Consequence:** a rebuilt APK **cannot be installed over the existing app** on the girlfriend's
  phone. Android will refuse the update with `INSTALL_FAILED_UPDATE_INCOMPATIBLE` /
  signature mismatch. The old app must be uninstalled, and uninstalling **wipes its data** -
  `notes.db` and the `magazines` table with her real `isOwned` / `condition` / `conditionScore`
  values. Get the data off the device (or exported from inside the running app) **before** anything
  is uninstalled. [CONFIRMED mechanism]
- The manifest declares no `android:allowBackup` and no `android:fullBackupContent`, so
  `allowBackup` defaults to true. `adb backup -f burda.ab com.example.burda` is therefore worth
  trying on her device (it is disabled on Android 12+ for most cases, so do not count on it).
  [CONFIRMED manifest state, INFERRED practical value]
- Recommendation for the rebuild: create a dedicated keystore now and commit its config, so this
  can never happen again.

---

## 2. Dependencies

### 2.1 Method

`NOTICES.Z` is the license roll-up. It contains two different kinds of names: pub packages
(collected from the resolved `package_config.json`, which includes dev dependencies) **and** Flutter
engine `third_party` directory names. Engine entries are identifiable: e.g. `spring_animation`
appears at NOTICES line 1064 inside the block headed
`accessibility / engine / image_picker / spring_animation / tonic / txt / url_launcher_web`, and its
own block at line 35032 is `Copyright (c) Meta Platforms, Inc. and affiliates.` - that is the
engine's `third_party/spring_animation`, not a pub package. The same applies to `url_launcher_linux`,
`url_launcher_platform_interface`, `url_launcher_windows`, `url_launcher_web`, `platform_detect`,
`fallback_root_certificates`, `web_locale_keymap`, `web_test_fonts`, `web_unicode`, `tonic`, `txt`,
`accessibility`, `sprintf`(also a pub package), `flatbuffers`, and all the C/C++ libraries
(skia, icu, harfbuzz, boringssl, angle, vulkan\*, libjpeg-turbo, libpng, libwebp, libjxl, zlib,
brotli, expat, perfetto, shaderc, spirv-cross, swiftshader, wuffs, xxhash, abseil-cpp, libcxx,
libcxxabi, double-conversion, cpu_features, freetype2, libtess2, etc1, etc_decoder, ffx_spd, fiat,
glfw, glslang, inja, json, khronos, rapidjson, libmicrohttpd, libXNVCtrl, libdatastore..., sqlite,
fuchsia_sdk, dart, engine, flutter, pkg, include, ceval). [CONFIRMED by inspecting the blocks]

The decisive second signal is the AOT snapshot itself. In a non-obfuscated release snapshot every
Dart library that survives tree shaking leaves its `package:<name>/...` script URI behind. Counting
those (`grep -oE "package:[a-z0-9_]+/" libapp_strings.txt | sort | uniq -c`) tells you which
packages actually ran, as opposed to which were merely declared.

### 2.2 Packages whose Dart code IS in the snapshot (really used)

| Package | `package:` URIs in snapshot | API surface seen | Confidence |
| --- | --- | --- | --- |
| flutter | 384 | - | [CONFIRMED] |
| burda (the app) | 29 | - | [CONFIRMED] |
| provider | 5 (+ `nested` 1) | `MultiProvider` (16546), `ChangeNotifierProvider` (9845), `Consumer` (11759), `Consumer2` (12734), `ProviderNotFoundException` (8607). No `Selector`. | [CONFIRMED] |
| sqflite / sqflite_common / sqflite_android / sqflite_platform_interface | 1 / 17 / 1 / 4 | `openDatabase` (13947), `getDatabasesPath` (2889), `sql_builder.dart`, `transaction.dart` | [CONFIRMED] |
| shared_preferences (+ _android, _platform_interface) | 1 / 4 / 4 | legacy `SharedPreferences` API - `package:shared_preferences/src/shared_preferences_legacy.dart` (14652), `SharedPreferences` (6174), `setBool` (10674) | [CONFIRMED] |
| path | 9 | - | [CONFIRMED] |
| path_provider (+ _android, _platform_interface) | 1 / 2 / 2 | `getApplicationDocumentsDirectory` (7869), `getTemporaryDirectory` (12999). **No** `getExternalStorageDirectory`, **no** `getDownloadsDirectory`. | [CONFIRMED] |
| intl | 8 | date only: `date_format.dart` (16517), `date_format_field.dart`, `date_symbols.dart`, `DateFormat` (13739). **No** `NumberFormat`, **no** number_symbols data. | [CONFIRMED] |
| uuid | 6 | `Uuid` (13742), `UuidV1` (13369), `UuidV4` (15003), `package:uuid/v4.dart` (5662) - the uuid 4.x layout | [CONFIRMED] |
| confetti | 5 | `ConfettiController` (7458), `ConfettiWidget` (12616), `ConfettiControllerState` (7458/9543), `blast_directionality.dart` (15711), app string `Confetti triggered for year ` (10151) | [CONFIRMED] |
| animate_do | 4 | see 2.5 | [CONFIRMED] |
| carousel_slider | 4 | see 2.5 | [CONFIRMED] |
| file_picker | 4 | `FilePicker` (15109), `FilePickerIO` (6176), `MethodChannelFilePicker` (4302), `pickFiles` (3635), `FilePickerResult` (5698), `PlatformFile` (6881), `FileType` (15184), `saveFile` (12148) | [CONFIRMED] |
| image_picker (+ _android, _platform_interface) | 1 / 2 / 5 | `ImagePicker` (10564), `pickImage` (14106), `ImageSource` (10468), pigeon channel `dev.flutter.pigeon.image_picker_android.ImagePickerApi.pickImages` (4172) | [CONFIRMED] |
| share_plus (+ _platform_interface) | 1 / 2 | `Share...` (6851), `shareXFiles` (2142), `ShareResult` (16065), `ShareResultStatus` (16504), `XFile` (12133), `MethodChannelShare` (16421) | [CONFIRMED] |
| package_info_plus (+ _platform_interface) | 1 / 3 | `PackageInfo` (9282), `PackageInfo(appName: ` (2879), `MethodChannelPackageInfo` (5578) | [CONFIRMED] |
| synchronized | 3 | transitive of sqflite_common | [CONFIRMED] |
| mime | 2 | transitive of share_plus_platform_interface | [INFERRED] |
| cross_file | 2 | transitive of share_plus / image_picker | [INFERRED] |
| collection | 2 | transitive | [CONFIRMED present] |
| characters | 4 | Flutter SDK dep | [CONFIRMED present] |
| material_color_utilities | 16 | Flutter SDK dep | [CONFIRMED present] |
| vector_math | 9 | Flutter SDK + confetti | [CONFIRMED present] |
| plugin_platform_interface | 1 | transitive | [CONFIRMED present] |

Two useful refinements:

- **image_picker is gallery-only.** Only the `ImagePickerApi.pickImages` pigeon channel name is in
  the snapshot; `takeImage`, `takeVideo`, `pickVideos`, `pickMedia` and `retrieveLostResults` are
  all absent. Combined with the presence of the string `gallery` (4845) and `camera` (11018) as
  enum names only, the app calls `ImagePicker().pickImage(source: ImageSource.gallery)` and never
  the camera. [INFERRED - strong; the camera branch of
  `ImagePickerAndroid.getImageFromSource` would have kept `takeImage` alive if it were reachable]
- **shared_preferences uses the legacy API**, not `SharedPreferencesAsync`.
  `shared_preferences_legacy.dart` is present, and the async classes
  (`SharedPreferencesAsyncAndroid`, 9623) are present only because `shared_preferences_android`
  registers both implementations from its plugin entry point. [INFERRED - the
  `shared_preferences_legacy.dart` URI is only reachable from `SharedPreferences.getInstance()`]
  This matters for data continuity: the legacy API reads the `FlutterSharedPreferences` XML file,
  while `SharedPreferencesAsync` reads androidx DataStore. Keeping the legacy API in the rebuild
  keeps her saved theme/settings readable.

### 2.3 Packages that were DECLARED but whose Dart code is NOT in the snapshot

These have a license block in `NOTICES` (so they were in `pubspec.lock` / `package_config.json`) yet
**zero** `package:<name>` strings in either `lib/arm64-v8a/libapp.so` or `lib/x86_64/libapp.so`:

| Package | NOTICES line | `package:` strings (arm64 / x86_64) | Verdict |
| --- | --- | --- | --- |
| mobile_scanner | - | 0 / 0 | declared, never used from Dart |
| permission_handler (+ _android, _apple, _html, _platform_interface, _windows) | - | 0 / 0 | declared, never used from Dart |
| sensors_plus (+ _platform_interface) | - | 0 / 0 | declared, never used from Dart |
| fl_chart | 7781 | 0 / 0 | declared, never used from Dart |
| google_fonts | 12285 | 0 / 0 | declared, never used from Dart |
| qr_flutter (+ qr) | 32910 / 32880 | 0 / 0 | declared, never used from Dart |
| dartz | 6179 | 0 / 0 | declared, never used from Dart |
| equatable | 6339 | 0 / 0 | transitive of fl_chart |
| flutter_launcher_icons | 8039 | 0 / 0 | dev dependency, does its work at generate time |

[CONFIRMED] for the string counts. [INFERRED] for "never used": in a non-obfuscated AOT snapshot,
any library with live code keeps its script URI, and every other declared package in this app did
keep one, so absence here is meaningful.

Supporting evidence from the other side of the boundary - these plugins' **native** code is in the
APK because plugin registration is generated from the pubspec, not from Dart usage. The
`GeneratedPluginRegistrant` in `classes.dex` registers all 11 Android plugins (confirmed by the
error strings `dexdump` recovers, e.g. `Error registering plugin mobile_scanner, dev.steenbakker.mobile_scanner.MobileScannerPlugin`,
`... permission_handler_android, com.baseflow.permissionhandler.PermissionHandlerPlugin`,
`... sensors_plus, dev.fluttercommunity.plus.sensors.SensorsPlugin`), and the corresponding channel
names live in the dex:

- `dev.fluttercommunity.plus/sensors/accelerometer`, `/gyroscope`, `/magnetometer`,
  `/user_accel`, `/method`
- `flutter.baseflow.com/permissions/methods`
- `dev.steenbakker.mobile_scanner/scanner/event`, `/scanner/method`

None of those three channel strings appear anywhere in `libapp_strings.txt`. By contrast the
channels for the plugins that **were** used do appear there:
`miguelruivo.flutter.plugins.filepicker` (5001), `dev.fluttercommunity.plus/share` (16443) and
`/share/unavailable` (6142), `com.tekartik.sqflite` (9695), `plugins.flutter.io/image_picker`
(9719), `dev.fluttercommunity.plus/package_info` (10610),
`plugins.flutter.io/shared_preferences` (13192), `plugins.flutter.io/path_provider` (15400).
[CONFIRMED]

**Direct answer to "how were sensors_plus and permission_handler used": they were not.** There is no
tilt handler for `floating_background.dart`, no shake gesture, no `Permission.camera.request()`.
They were added to `pubspec.yaml` - most likely while planning a barcode scanner for adding issues
(mobile_scanner + permission_handler + camera) and some chart/QR features (fl_chart, qr_flutter) -
and either abandoned before any Dart code was written, or the code was deleted again before this
build. [INFERRED for "declared and unused", [GUESS] for the intent behind it]

### 2.4 Package versions of the originals

`NOTICES` does not carry version numbers and `pubspec.lock` is not in the APK, so exact pub versions
are mostly unrecoverable. The bundled Android artifacts do pin some of them:

| Evidence | Version | What it pins | Confidence |
| --- | --- | --- | --- |
| `META-INF/androidx.camera_camera-core.version` etc. | camera-core / camera-camera2 / camera-lifecycle **1.3.4** | mobile_scanner 5.x (6.x/7.x moved to CameraX 1.4.x) | [INFERRED] |
| `barcode-scanning.properties` | ML Kit barcode-scanning **17.3.0** (bundled model, hence `libbarhopper_v3.so`) | mobile_scanner 5.x, bundled variant | [CONFIRMED artifact, INFERRED mapping |
| `play-services-mlkit-barcode-scanning.properties` | **18.3.1** | same | [CONFIRMED] |
| `META-INF/androidx.datastore_*.version` = **1.1.3** plus `libdatastore_shared_counter.so` | - | shared_preferences_android >= 2.4.0 (the DataStore rewrite), so shared_preferences 2.5.x | [INFERRED] |
| `META-INF/androidx.exifinterface_exifinterface.version` = **1.3.7** | - | image_picker_android 0.8.12.x | [INFERRED] |
| `META-INF/androidx.core_core.version` = **1.13.1** | - | source of the `com.example.burda.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` permission in the manifest | [INFERRED] |
| `CarouselSliderController` / `CarouselSliderControllerImpl` in the snapshot (11545, 11872, 8770) | - | **carousel_slider >= 5.0.0** - these classes were called `CarouselController`/`CarouselControllerImpl` up to 4.2.1 and were renamed in 5.0.0 to stop clashing with Flutter 3.24's `material` `CarouselController` | [CONFIRMED evidence, INFERRED mapping - high confidence] |
| `AnimateDoState` mixin + `src/animations/` + `src/types/animate_do_mixins.dart` layout | - | animate_do >= 3.3.x (the `src/` split); 3.x or 4.x | [INFERRED] |
| `package:uuid/v1.dart`, `v4.dart`, `parsing.dart`, `rng.dart`, `data.dart` | - | uuid 4.x | [INFERRED] |
| `Share`/`shareXFiles` static API with no `SharePlus` or `ShareParams` anywhere | - | **share_plus <= 10.x** | [CONFIRMED] |
| Other androidx versions (for the record) | activity 1.9.3, appcompat 1.6.1, fragment 1.7.1, lifecycle 2.7.0, preference 1.2.1, window 1.2.0, profileinstaller 1.3.1, startup 1.1.1, tracing 1.2.0, emoji2 1.2.0, savedstate 1.2.1 | - | [CONFIRMED] |

Also worth recording so nobody chases a ghost: the `firebase-*.properties` files in the APK root
come from ML Kit's transitive `firebase-components` / `firebase-encoders` dependencies. There is no
`google-services.json` and no `google_app_id` / `gcm_defaultSenderId` resource in
`resources.arsc`. **Firebase was not used.** [CONFIRMED]

### 2.5 What each used package was for

- **provider** - state management. `MultiProvider` at the root with four `ChangeNotifierProvider`s
  matching `providers/{bottom_navigation,dress_animation,magazine,theme}_provider.dart`. `Consumer`
  and `Consumer2` at the widget level. [CONFIRMED API, INFERRED wiring]
- **sqflite** - the `magazines` table (the `ALTER TABLE magazines_temp RENAME TO magazines` string
  sits at line 5167, right next to the `condition` column name at 5269) and the separate `notes.db`.
- **path** - joining `getDatabasesPath()`/documents dir with the db file names.
- **path_provider** - `getApplicationDocumentsDirectory()` and `getTemporaryDirectory()` only. No
  external storage, no downloads dir. So exports are written to app-private storage or the cache and
  then handed to the system via share_plus. [CONFIRMED]
- **shared_preferences** - theme mode and other small settings, via the legacy sync-loaded API.
- **intl** - `DateFormat` only, for `dateAdded`. No number formatting, no localization.
- **uuid** - note ids (`models/note.dart`).
- **confetti** - the celebration when a year's collection completes. The app's own string
  `Confetti triggered for year ` (10151) and the private method `_checkAndTriggerConfetti@465443711`
  (5998) confirm the trigger is per year. [CONFIRMED]
- **animate_do** - entrance animations. Definitely `FadeIn` (3200, state class at 11715),
  `FadeInDown` (14182, state class at 10676) and `ZoomIn` (4977, state class at 2532/4909)
  [CONFIRMED]. `BounceInDown` (5270) and `ZoomOut` (10255) appear as class names and
  `animate_do_bounces.dart` is retained, which is only explicable if a bounce widget is live, so
  `BounceInDown` is probably used too [INFERRED]; `ZoomOut` is weaker [GUESS]. No `onFinish`,
  `AnimateDoController` or `AnimateDoDirection` strings, so **only the simple parameters**
  (`child`, `duration`, `delay`, maybe `animate`, `from`) were passed. [CONFIRMED by absence]
- **carousel_slider** - the cover carousel. `CarouselSlider.builder` (14177), `CarouselOptions`
  (10862), `CarouselSliderController` (11545), `CarouselPageChangedReason` (9257).
- **file_picker** - `FilePicker.platform.pickFiles(...)` for import, and very likely
  `saveFile(...)` for export (`saveFile` at 12148; slightly weaker because it is also an abstract
  member name on a retained class) [INFERRED].
- **image_picker** - `pickImage(source: ImageSource.gallery)`, presumably to attach a custom cover
  or a photo to a note.
- **share_plus** - `Share.shareXFiles([...])` and a `ShareResult`/`ShareResultStatus` check, i.e.
  sharing an exported file out of the app.
- **package_info_plus** - `PackageInfo.fromPlatform()` to show app name/version on the settings
  screen.
- **mime / cross_file / synchronized / nested / collection / vector_math / characters /
  material_color_utilities / plugin_platform_interface** - transitive only, no direct use needed in
  the rebuild.

---

## 3. Android configuration

### 3.1 Manifest (from `aapt2 dump xmltree --file AndroidManifest.xml`)

Application node:

```
<application android:label="Burda Style"
             android:icon="@mipmap/ic_launcher"
             android:name="android.app.Application"
             android:extractNativeLibs="true"
             android:appComponentFactory="androidx.core.app.CoreComponentFactory">
```

- [CONFIRMED] `android:name="android.app.Application"` - **no custom Application class**. Nothing was
  initialised on the Android side.
- [CONFIRMED] label `Burda Style`, icon `@mipmap/ic_launcher`.
- [CONFIRMED] No `android:allowBackup`, no `android:usesCleartextTraffic`, no `android:debuggable`,
  no `android:requestLegacyExternalStorage`.

Launcher activity:

```
<activity android:name="com.example.burda.MainActivity"
          android:theme="@style/LaunchTheme"
          android:exported="true"
          android:taskAffinity=""
          android:launchMode="standard"            (1)
          android:configChanges="0x40003fb4"
          android:windowSoftInputMode="adjustResize" (0x10)
          android:hardwareAccelerated="true">
    <meta-data android:name="io.flutter.embedding.android.NormalTheme"
               android:resource="@style/NormalTheme" />
    <intent-filter> MAIN / LAUNCHER </intent-filter>
</activity>
<meta-data android:name="flutterEmbedding" android:value="2" />
```

This is byte-for-byte the stock Flutter Android template (v2 embedding, `LaunchTheme` +
`NormalTheme` meta-data, `taskAffinity=""`, `adjustResize`). **No custom manifest edits at the
activity level.** [CONFIRMED values, INFERRED that it is the untouched template]

Permissions, in merge order:

| Permission / node | Source | Confidence |
| --- | --- | --- |
| `android.permission.READ_EXTERNAL_STORAGE` | file_picker's library manifest | [INFERRED] |
| `<queries>` `PROCESS_TEXT` + `text/plain` | Flutter embedding's library manifest | [INFERRED] |
| `<queries>` `GET_CONTENT` + `*/*` | file_picker's library manifest | [INFERRED] |
| `android.permission.CAMERA` + `<uses-feature android:name="android.hardware.camera" android:required="false"/>` | mobile_scanner's library manifest | [INFERRED] |
| `com.example.burda.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` (declared + used, `protectionLevel=signature`) | androidx.core 1.13.1 | [INFERRED] |
| `android.permission.ACCESS_NETWORK_STATE`, `android.permission.INTERNET` | play-services-basement 18.4.0 / ML Kit, pulled in by mobile_scanner | [INFERRED] |

The inference for each is the merge order, which matches the alphabetical plugin registration order
(`file_picker`, `flutter_plugin_android_lifecycle`, `image_picker_android`, `mobile_scanner`, ...)
recovered from `GeneratedPluginRegistrant`. [INFERRED]

**So the app itself declared no permissions at all.** Every permission in this APK arrived from a
library manifest. That is a meaningful finding for the rebuild: the original
`android/app/src/main/AndroidManifest.xml` had no `<uses-permission>` lines.
[INFERRED - strong; the app-level nodes in a merged manifest come first, and the first
`uses-permission` is attributable to a library]

### 3.2 Providers, services and receivers

All of these come from plugin library manifests, none from the app:

| Node | Type | Authority / detail |
| --- | --- | --- |
| `io.flutter.plugins.imagepicker.ImagePickerFileProvider` | provider | `com.example.burda.flutter.image_provider`, `grantUriPermissions=true`, paths = `<cache-path name="cached_files" path="." />` |
| `dev.fluttercommunity.plus.share.ShareFileProvider` | provider | `com.example.burda.flutter.share_provider`, paths = `<cache-path name="cache" path="share_plus/" />` |
| `dev.fluttercommunity.plus.share.SharePlusPendingIntent` | receiver | action `EXTRA_CHOSEN_COMPONENT` |
| `com.google.mlkit.common.internal.MlKitInitProvider` | provider | `com.example.burda.mlkitinitprovider`, `initOrder=99` |
| `androidx.startup.InitializationProvider` | provider | `com.example.burda.androidx-startup`, with emoji2 / ProcessLifecycle / ProfileInstaller initializers |
| `com.google.android.gms.metadata.ModuleDependencies` | service (disabled) | `photopicker_activity:0:required` - image_picker's Android photo picker module hint |
| `androidx.camera.core.impl.MetadataHolderService` | service (disabled) | `Camera2Config$DefaultProvider` |
| `com.google.mlkit.common.internal.MlKitComponentDiscoveryService` | service | BarcodeRegistrar, VisionCommonRegistrar, CommonComponentRegistrar |
| `com.google.android.gms.common.api.GoogleApiActivity` | activity | - |
| `androidx.profileinstaller.ProfileInstallReceiver` | receiver | baseline profile install |
| `com.google.android.datatransport.runtime.*` | service + receiver | ML Kit telemetry transport |
| `<uses-library androidx.window.extensions / androidx.window.sidecar required=false>` | - | androidx.window 1.2.0 |
| `<meta-data com.google.android.gms.version = 12451000>` | - | play-services |

[CONFIRMED all of the above from the xmltree dump and `res.txt`]

### 3.3 Themes and splash

```
style/LaunchTheme  (0x7f0e00a2)
  ()      parent=@android:style/Theme.Light.NoTitleBar   android:windowBackground=@drawable/launch_background
  (night) parent=@android:style/Theme.Black.NoTitleBar   android:windowBackground=@drawable/launch_background

style/NormalTheme  (0x7f0e00a3)
  ()      parent=@android:style/Theme.Light.NoTitleBar   android:windowBackground=?android:attr/colorBackground
  (night) parent=@android:style/Theme.Black.NoTitleBar   android:windowBackground=?android:attr/colorBackground

drawable/launch_background (0x7f070073) -> res/Zn.xml
  <layer-list><item android:drawable="?android:attr/colorBackground" /></layer-list>
```

- [CONFIRMED] The `(night)` configuration exists for both themes, so `values-night/styles.xml` was
  present - i.e. the modern Flutter template, unmodified.
- [CONFIRMED] `launch_background` is a single-item layer-list pointing at the theme background.
  **There is no splash image and no branded splash colour.** The splash is a plain white
  (or black in dark mode) screen. Do not add a splash to the rebuild.
- [CONFIRMED] Only one configuration of `launch_background` exists. The template ships both
  `drawable/` and `drawable-v21/` copies; with `minSdk 21` the `-v21` qualifier is redundant and the
  AGP resource optimizer collapses it. [INFERRED for the reason]

### 3.4 Launcher icon

`mipmap/ic_launcher` (0x7f0c0000) exists at five densities and **there is no adaptive icon**: no
`mipmap-anydpi-v26` XML, no `ic_launcher_foreground`, no `ic_launcher_background`, no
`values/ic_launcher_background.xml` colour. [CONFIRMED - the only `ic_launcher` resource in
`aapt2 dump resources` is the mipmap PNG set]

Extracted to `/home/x3kk3x/Desktop/Burda/recovery/extracted/launcher/`:

| File | Density | Size | md5 |
| --- | --- | --- | --- |
| `ic_launcher_mdpi.png` | mdpi | 48x48 RGBA | `9724d861953f5af8bc912d94d0cd87e5` |
| `ic_launcher_hdpi.png` | hdpi | 72x72 RGBA | `4364adb4ccea7b7f6f5ce5926e4e9b6f` |
| `ic_launcher_xhdpi.png` | xhdpi | 96x96 RGBA | `4bcff6ea0fae3c049303a47eb59da6c1` |
| `ic_launcher_xxhdpi.png` | xxhdpi | 144x144 RGBA | `4b15322f7543cb5c88213bd956415ae5` |
| `ic_launcher_xxxhdpi.png` | xxxhdpi | 192x192 RGBA | `a0e151e77773e199130d1a8504cd942a` |

**The icon is `assets/icon/icon.png`.** Visual comparison of `ic_launcher_xxxhdpi.png` against
`/home/x3kk3x/Desktop/Burda/assets/icon/icon.png` (512x512 RGBA, md5
`60f081062b43a4aea8dd2723d1fdbf4a`) shows the same artwork: a sketch-hatched periwinkle/blue dress
with a heavy dark outline on a transparent background. The mipmaps are plain downscales - no
padding, no background plate, no masking. [CONFIRMED by visual inspection; the exact resampler is
not recoverable so the bytes will not match after regeneration]

Combined with `flutter_launcher_icons` being in `NOTICES` (line 8039), the original almost certainly
had:

```yaml
dev_dependencies:
  flutter_launcher_icons: ^<something>

flutter_launcher_icons:
  android: true            # or "ic_launcher"
  ios: false               # [GUESS] - no iOS evidence survives
  image_path: "assets/icon/icon.png"
```

with **no** `adaptive_icon_background` / `adaptive_icon_foreground` (those would have produced the
v26 XML and the extra drawables). [INFERRED - strong]

### 3.5 Retained Material icons (24) - a bonus for the UI rebuild

Parsed from the `cmap` of the tree-shaken `MaterialIcons-Regular.otf` (3,480 bytes, CFF outlines,
24 codepoints) and mapped through the local Flutter SDK's
`packages/flutter/lib/src/material/icons.dart`:

| Codepoint | `Icons.` name |
| --- | --- |
| 0xe048 | add_a_photo |
| 0xe092 | arrow_back |
| 0xe098 | arrow_drop_down |
| 0xe09d | arrow_left |
| 0xe09e | arrow_right |
| 0xe16a | close |
| 0xe172 | cloud_download |
| 0xe1b9 | delete |
| 0xe21a | edit |
| 0xe237 | error |
| 0xe25b | favorite |
| 0xe2bc | format_quote |
| 0xe2ea | grid_view |
| 0xe33d | info_outline |
| 0xe384 | list |
| 0xe393 | local_florist |
| 0xe3ae | lock |
| 0xe3dc | menu |
| 0xe404 | more_vert |
| 0xe46b | palette |
| 0xe593 | share |
| 0xe6ae | view_carousel |
| 0xf0516 | heart_broken |
| 0x0f570 | arrow_back_ios_new_rounded |

[CONFIRMED for the codepoints. INFERRED for the names - the mapping comes from the currently
installed stable SDK at `/home/x3kk3x/fvm/versions/stable`, and Material icon codepoints are stable
across Flutter versions. The full list is exhaustive: these are the **only** `Icons.*` glyphs the
app renders. `add_a_photo` corroborates the image_picker usage, `cloud_download` and `share`
corroborate import/export, `format_quote` matches `quote_display.dart`, `view_carousel` and
`grid_view` match the carousel/grid toggle, `heart_broken` and `favorite` match
`raining_hearts.dart`.]

### 3.6 Other flutter_assets facts

- `NativeAssetsManifest.json` = `{"format-version":[1,0,0],"native-assets":{}}` - no FFI native
  assets. [CONFIRMED]
- `shaders/ink_sparkle.frag` - the default Material ink sparkle shader, always bundled. No custom
  shaders. [CONFIRMED]
- `AssetManifest.json` has 248 entries, all under `assets/`: `magazines.json` 1, `quotes.json` 1,
  `covers/` 184, `fonts/` 19, `icon/` 42, `images/` 1. Matches the already-verified asset copy.
  [CONFIRMED]
- `FontManifest.json` declares `MaterialIcons` plus the 8 app families exactly as the new
  `pubspec.yaml` does. **The new pubspec's `fonts:` section is already correct.**
  `ZillaSlabHighlight-Regular/Bold` are bundled via the `assets/fonts/` folder entry with no family
  declaration, so they can only have been used through `TextStyle(fontFamily: ...)` against a
  non-declared family, which does nothing - i.e. they are dead weight but harmless. [CONFIRMED]
- `uses-material-design: true` was set (MaterialIcons font is bundled). [CONFIRMED]

---

## 4. Review of the new `/home/x3kk3x/Desktop/Burda/pubspec.yaml`

Read-only review, no edits made.

### 4.1 Verdict summary

| Finding | Severity |
| --- | --- |
| `share_plus: ^13.3.0` is a hard API break versus the original's `Share.shareXFiles(...)` | **high - code will not compile** |
| `flutter_launcher_icons` is missing from `dev_dependencies`, so `mipmap/ic_launcher` will be the default Flutter "F" logo, not the dress | **high - visible regression** |
| `mobile_scanner`, `permission_handler`, `sensors_plus` were unused in the original and add ~20 MB of native code plus the CAMERA permission | **medium - decide deliberately** |
| `file_picker: ^13.1.0` is 5 majors past the original's 8.x-era structure; call sites need verifying | **medium - verify** |
| `package_info_plus: ^10.2.1` and `animate_do: ^5.1.0` are major bumps I cannot verify from here | **medium - verify** |
| `carousel_slider: ^5.1.2` is **not** a migration risk - the original already used the 5.x API | good news, correcting the brief |
| `cupertino_icons` and `flutter_lints` are new additions not in the original | cosmetic |
| `fl_chart`, `google_fonts`, `qr_flutter`, `dartz` are missing versus the original but were never used | correctly omitted |
| `intl`, `provider`, `sqflite`, `path`, `path_provider`, `shared_preferences`, `uuid`, `confetti`, `image_picker` are same-major or API-stable | fine |

### 4.2 Missing versus the original

- **`flutter_launcher_icons` (dev_dependency) - genuinely needed.** Without it there is no step that
  produces `android/app/src/main/res/mipmap-*/ic_launcher.png`, and the app will ship the default
  Flutter launcher icon. Either add it back with `image_path: "assets/icon/icon.png"`, or drop the
  extracted PNGs from `/home/x3kk3x/Desktop/Burda/recovery/extracted/launcher/` straight into
  `android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png` (that gives
  byte-identical icons, which is strictly better for fidelity). [CONFIRMED gap]
- `fl_chart`, `google_fonts`, `qr_flutter`, `dartz` - in the original's lockfile, zero Dart code in
  the snapshot. **Correctly omitted. Do not add them.** [CONFIRMED]
- `cupertino_icons` is in the new pubspec but has no `NOTICES` block, so the original had it removed
  from the template. Harmless either way (unused font assets are tree-shaken), but it is a
  difference. [CONFIRMED]
- `flutter_lints` / `lints` likewise have no `NOTICES` block, so the original had them removed.
  Keeping `flutter_lints: ^6.0.0` is an improvement, not a regression - just expect the recovered
  code to trip lints the original never saw. [CONFIRMED absence]

### 4.3 Unnecessary in the new pubspec

`mobile_scanner: ^7.4.2`, `permission_handler: ^13.0.2` and `sensors_plus: ^7.1.0` had **zero** Dart
usage in the original (section 2.3). Keeping them is not wrong, but it is not free:

- ~20.2 MB of uncompressed native code just for ML Kit's bundled barcode model
  (`libbarhopper_v3.so`: 4,946,720 arm64 + 3,244,440 armeabi-v7a + 6,122,368 x86 + 5,909,280 x86_64),
  plus CameraX, play-services and the ML Kit dex. That is the bulk of why this APK is 74 MB.
  [CONFIRMED sizes]
- They are what put `CAMERA`, `INTERNET` and `ACCESS_NETWORK_STATE` in the manifest. A
  collection-tracker asking for the camera and the network is a worse-looking install prompt, and
  the app never used either.
- **One real behavioural coupling to be aware of before dropping mobile_scanner:** because
  `android.permission.CAMERA` is declared in this APK's merged manifest, Android requires it to be
  *granted* before `ACTION_IMAGE_CAPTURE` will work. The original never used
  `ImageSource.camera` (section 2.2), so nothing in the original depended on that. Dropping
  mobile_scanner removes the CAMERA declaration, which if anything makes a future camera capture
  path easier. No regression either way. [INFERRED]

My recommendation: drop all three, keep the resulting pubspec honest, and re-add whichever one is
actually wanted if x3kk decides to build the barcode-scan feature that was clearly on the wish list.
That is a decision for x3kk, not something to do silently.

### 4.4 Breaking changes the rebuild must handle

**share_plus 10.x -> 13.3.0 - [CONFIRMED problem]**

The original called the static API. The snapshot has `Share...` (6851), `shareXFiles` (2142),
`ShareResult` (16065), `ShareResultStatus` (16504) and **no** `SharePlus` and **no** `ShareParams`
(`grep -c` returns 0 for both in `libapp_strings.txt`). share_plus 11.0.0 replaced the static
`Share.share*` methods with a singleton + params object, and the old `Share` class does not survive
to 13.x. So old code shaped like:

```dart
final result = await Share.shareXFiles(
  [XFile(file.path)],
  text: 'My Burda Style collection',
  subject: 'Burda collection export',
);
if (result.status == ShareResultStatus.success) { ... }
```

becomes, on 13.x:

```dart
final result = await SharePlus.instance.share(
  ShareParams(
    files: [XFile(file.path)],
    text: 'My Burda Style collection',
    subject: 'Burda collection export',
  ),
);
if (result.status == ShareResultStatus.success) { ... }
```

`XFile` (from `cross_file`, re-exported by share_plus) and `ShareResult`/`ShareResultStatus` keep
their names. [CONFIRMED that the original used the pre-11 API. The 11.x replacement shape above is
[INFERRED] from the documented 11.0.0 migration; verify the exact `ShareParams` field names against
the resolved version's API docs before writing the call, since I cannot read 13.3.0's source from
here.]

**carousel_slider - [CONFIRMED non-problem, correcting the brief]**

The brief flagged "carousel_slider 5.x CarouselSlider API and its clash with Flutter's own
CarouselController" as a migration risk. It is not one. The original snapshot already contains
`CarouselSliderController` (11545), `CarouselSliderControllerImpl` (11872, 8770) and
`CarouselSliderController.` (6353) - the **5.x** names. The 4.x names `CarouselController` /
`CarouselControllerImpl` do not appear. The original was already on carousel_slider 5.x, built
against Flutter 3.29 whose `material` library also exports `CarouselController`. So:

- `CarouselSlider`, `CarouselSlider.builder`, `CarouselOptions`, `CarouselSliderController` and
  `CarouselPageChangedReason` are all the same names on 5.1.2 as in the original.
- The only thing to watch is that `import 'package:flutter/material.dart'` and
  `import 'package:carousel_slider/carousel_slider.dart'` in the same file still both export a
  `CarouselController`, so a bare `CarouselController` reference is ambiguous. The original avoided
  this by using `CarouselSliderController`. Keep doing that.
  [CONFIRMED for the names, INFERRED for the ambiguity mechanics]

**animate_do 3.x/4.x -> 5.1.0 - [verify, do not assume]**

The original used only `FadeIn`, `FadeInDown`, `ZoomIn` and (probably) `BounceInDown`, with only
the plain parameters - there is no `onFinish`, `AnimateDoController` or `AnimateDoDirection` string
in the snapshot. Those widget names and the `child` / `duration` / `delay` parameters have been
stable across animate_do 3.x and 4.x. I do **not** have reliable knowledge of what animate_do 5.x
changed, so I am not going to invent an API. Concrete check for the rebuild: after `pub get`, open
`~/.pub-cache/hosted/pub.dev/animate_do-5.1.0/lib/animate_do.dart` and confirm `FadeIn`,
`FadeInDown`, `ZoomIn`, `BounceInDown` still exist with `child`, `duration`, `delay`. Low risk
because the usage is so shallow. [INFERRED risk level, honest unknown on the 5.x API]

**file_picker 8.x-era -> 13.1.0 - [verify]**

Original internals in the snapshot: `package:file_picker/src/file_picker.dart`,
`src/file_picker_io.dart` (class `FilePickerIO`), `src/file_picker_result.dart`,
`src/platform_file.dart`, and `MethodChannelFilePicker`. That monolithic `src/file_picker_io.dart`
structure is the pre-federated file_picker (8.x and earlier). By 13.x the package has been through
several restructurings. What I can say with confidence:

- The original call shape was `FilePicker.platform.pickFiles(...)` returning
  `FilePickerResult?` with `.files` of `PlatformFile` (which has `.path`, `.name`, and was
  constructed via `PlatformFile.fromMap`, seen at 10535). [CONFIRMED]
- `FileType` was referenced (15184, 16136), so a `type:` argument was passed - most likely
  `FileType.custom` with `allowedExtensions: ['json']` for importing a backup. [INFERRED for
  `FileType` being passed; [GUESS] for `custom`/`json`]
- `saveFile` appears (12148) so an export-to-chosen-location path probably existed. [INFERRED]
- I cannot verify file_picker 13.1.0's current signatures from here. Check
  `~/.pub-cache/hosted/pub.dev/file_picker-13.1.0/` for whether `FilePicker.platform` is still the
  entry point and whether `saveFile` is still supported on Android before committing to it. If
  `saveFile` has changed or regressed, the safe fallback that matches the original's behaviour
  anyway is: write the export into `getTemporaryDirectory()` (which the original definitely used)
  and hand it to share_plus. [honest unknown]

**package_info_plus 8.x-era -> 10.2.1 - [verify]**

The original used the plain `PackageInfo.fromPlatform()` -> `.appName` / `.packageName` / `.version`
/ `.buildNumber` surface, which has been stable for many majors (the majors were mostly about
platform support, `installerStore` and `installTime`). I do not have verified knowledge of 10.x, so:
check `~/.pub-cache/hosted/pub.dev/package_info_plus-10.2.1/lib/package_info_plus.dart` for
`fromPlatform()`. Expected to be a no-op migration. [INFERRED low risk, honest unknown]

**permission_handler 13.x / mobile_scanner 7.x / sensors_plus 7.x - [CONFIRMED non-issue]**

There is no original code to migrate. If they are kept, nothing needs writing; if a scanner is built
later, write it against the version's current docs rather than against any recovered code, because
none exists.

**No-migration-needed list [INFERRED, same major or API-stable]**

- `provider ^6.1.5+1` - original was 6.1.x. `MultiProvider`, `ChangeNotifierProvider`, `Consumer`,
  `Consumer2` unchanged.
- `sqflite ^2.4.4` - original 2.4.x. `openDatabase`, `onCreate`, `onUpgrade`, `rawQuery`, `insert`,
  `update`, `delete`, `batch` unchanged.
- `shared_preferences ^2.5.5` - original 2.5.x. Keep using the legacy
  `SharedPreferences.getInstance()` API, both for source fidelity and because it reads the same
  on-device XML store (section 2.2).
- `path ^1.9.1`, `path_provider ^2.1.6` - unchanged.
- `intl ^0.20.3` - original was 0.19.x or 0.20.x. Only `DateFormat` is used and its API did not
  change; the 0.20 breaking changes were in the number/currency area, which the app never touched.
- `uuid ^4.6.0` - original 4.x. `Uuid().v4()` unchanged.
- `confetti ^0.8.0` - `ConfettiController(duration:)`, `ConfettiWidget(confettiController:, blastDirectionality:, ...)`
  and `BlastDirectionality` all match the snapshot's file layout. Low risk. [INFERRED]
- `image_picker ^1.2.3` - original 1.x. `ImagePicker().pickImage(source: ImageSource.gallery)`
  unchanged.

### 4.5 One more thing worth checking outside the pubspec

`minSdk`. The original is **21**, and mobile_scanner 5.x / permission_handler were both happy there.
A project scaffolded on a much newer Flutter will default `flutter.minSdkVersion` higher (24+), and
mobile_scanner 7.x and permission_handler 13.x will each impose their own floor. That is fine for a
personal app on a modern phone, but if the target device is old, check
`android/app/build.gradle.kts` after the first build and note that raising minSdk is a one-way door
for that device. [CONFIRMED original value; [GUESS] on the new default]

---

## 5. Files this slice produced

- This report: `/home/x3kk3x/Desktop/Burda/recovery/reports/platform.md`
- Launcher icons, ready to drop into `android/app/src/main/res/mipmap-*/ic_launcher.png`:
  - `/home/x3kk3x/Desktop/Burda/recovery/extracted/launcher/ic_launcher_mdpi.png`
  - `/home/x3kk3x/Desktop/Burda/recovery/extracted/launcher/ic_launcher_hdpi.png`
  - `/home/x3kk3x/Desktop/Burda/recovery/extracted/launcher/ic_launcher_xhdpi.png`
  - `/home/x3kk3x/Desktop/Burda/recovery/extracted/launcher/ic_launcher_xxhdpi.png`
  - `/home/x3kk3x/Desktop/Burda/recovery/extracted/launcher/ic_launcher_xxxhdpi.png`

Nothing outside `/home/x3kk3x/Desktop/Burda/recovery/` was created or modified. No packages were
installed, no builds were run.
