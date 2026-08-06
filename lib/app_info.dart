/// The user-facing app version shown in the UI (Settings → About).
///
/// This must equal `version:` in pubspec.yaml — the version the phone and the
/// Play listing actually report. Asking people to keep two files in step by
/// hand does not work: this constant sat at 1.4.0 once, then at 1.48.0 while
/// the app itself shipped as 1.60.0, telling every user the wrong thing.
/// `test/app_version_test.dart` now reads pubspec.yaml and fails the moment
/// the two disagree, so a bump that forgets this line can't reach a release.
const String kAppVersion = '1.64.0';

/// The brand motto. Rendered (in English, as a brand line) on the splash,
/// the PDF export and the shareable cards.
const String kAppMotto =
    'The private, offline budget tracker that does the work for you.';
