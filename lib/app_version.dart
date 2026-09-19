/// The version this build reports, and the one an update is measured against.
///
/// Kept in step with the `version:` line in `pubspec.yaml` by a test, so
/// changing one without the other fails the suite rather than shipping an app
/// that cannot tell whether it is out of date.
const String kAppVersion = '1.3.0';
