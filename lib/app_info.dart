/// Single source of truth for the user-facing app version string shown in the
/// UI (e.g. Settings → About). Keep this in sync with `version:` in
/// pubspec.yaml on every release bump — referencing one constant stops the
/// Settings screen from drifting out of date (it had been stuck at 1.4.0).
const String kAppVersion = '1.26.4';

/// The brand motto. Rendered (in English, as a brand line) on the splash,
/// the PDF export and the shareable cards.
const String kAppMotto =
    'The private, offline budget tracker that does the work for you.';
