import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/locale_provider.dart';
import 'app_strings.dart';

/// `context.l10n.someString` — the active language's [AppStrings]. Listens to
/// [LocaleProvider] so widgets rebuild when the language changes.
extension L10nContext on BuildContext {
  AppStrings get l10n => watch<LocaleProvider>().strings;
}
