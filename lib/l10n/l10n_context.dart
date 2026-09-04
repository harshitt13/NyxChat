import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

/// `context.l10n` resolves the translated strings of the active locale.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}