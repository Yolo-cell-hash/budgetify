import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/locale_provider.dart';
import 'app_strings.dart';

/// `context.l10n.someString` — the active language's [AppStrings]. Listens to
/// [LocaleProvider] so widgets rebuild when the language changes.
///
/// Use [l10n] inside `build` (it `watch`es, so the subtree rebuilds on a
/// language change). Use [l10nRead] from event handlers, async callbacks,
/// toasts and dialog builders, where `watch` is illegal — it `read`s the same
/// table without subscribing.
extension L10nContext on BuildContext {
  AppStrings get l10n => watch<LocaleProvider>().strings;

  /// Non-listening variant for use outside `build` (callbacks, async methods,
  /// `showDialog`/toast builders). Reads the current language without
  /// subscribing this context to rebuilds.
  AppStrings get l10nRead => read<LocaleProvider>().strings;
}
