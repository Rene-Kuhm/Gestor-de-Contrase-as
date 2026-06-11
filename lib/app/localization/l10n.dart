import 'package:flutter/widgets.dart';
import 'package:gestor_contrasenas/l10n/app_localizations.dart';

/// App-wide i18n accessor. Hides the `AppLocalizations.of(context)!`
/// non-null assertion behind a property so widgets can write
/// `context.l10n.someKey` instead of `AppLocalizations.of(context)!.someKey`.
extension L10nBuildContext on BuildContext {
  /// The current [AppLocalizations] for the widget tree rooted at
  /// this context. Throws (via the `!`) when no [Localizations]
  /// ancestor is in scope — which only happens if the caller is
  /// outside a `MaterialApp` (or equivalent), in which case the
  /// build should fail loudly rather than silently render English.
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
