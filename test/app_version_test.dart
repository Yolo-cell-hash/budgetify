import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/app_info.dart';

/// The version shown in Settings → About has to be the version the user is
/// actually running. It is a separate Dart constant from pubspec.yaml's
/// `version:` (which is what the phone and the Play listing report), and
/// keeping the two in step by hand has failed twice: the constant sat at
/// 1.4.0 once, and at 1.48.0 while the app shipped as 1.60.0.
///
/// So the pairing is checked here instead of remembered. Bump pubspec.yaml
/// without bumping [kAppVersion] and the suite goes red before the build does.
void main() {
  /// The `version:` line from pubspec.yaml, split into its name and build
  /// parts (`1.61.0+69` → `('1.61.0', '69')`).
  (String, String?) pubspecVersion() {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true)
        .firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec.yaml has no `version:` line');
    final raw = match!.group(1)!;
    final parts = raw.split('+');
    return (parts.first, parts.length > 1 ? parts[1] : null);
  }

  group('app version', () {
    test('Settings shows the same version pubspec declares', () {
      final (name, _) = pubspecVersion();
      expect(
        kAppVersion,
        name,
        reason: 'kAppVersion in lib/app_info.dart is what Settings → About '
            'displays. It must match `version:` in pubspec.yaml — bump both, '
            'or users are told they are on a version that does not exist.',
      );
    });

    test('pubspec carries a build number for the Play upload', () {
      final (_, build) = pubspecVersion();
      expect(
        build,
        isNotNull,
        reason: 'version: needs a +<build> suffix; Play rejects an upload '
            'whose version code did not increase.',
      );
      expect(int.tryParse(build!), isNotNull,
          reason: 'the build number must be an integer');
    });

    test('the version reads as a plain semantic version', () {
      expect(RegExp(r'^\d+\.\d+\.\d+$').hasMatch(kAppVersion), isTrue,
          reason: 'kAppVersion is rendered straight into the Settings row, '
              'so it should be just the number — no build suffix, no v prefix');
    });
  });
}
