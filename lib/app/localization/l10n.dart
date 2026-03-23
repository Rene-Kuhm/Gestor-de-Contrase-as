import 'package:flutter/widgets.dart';
import 'package:gestor_contrasenas/l10n/app_localizations.dart';

extension L10nBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
