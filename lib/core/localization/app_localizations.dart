import 'package:flutter/material.dart';

import 'app_strings.dart';

/// Minimal localization delegate backed by [AppStrings]. Arabic is the primary
/// locale; English is secondary.
class AppLocalizations {
  final Locale locale;
  const AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizations(Locale('ar'));
  }

  static const List<Locale> supportedLocales = [Locale('ar'), Locale('en')];

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  Map<String, String> get _map =>
      AppStrings.values[locale.languageCode] ?? AppStrings.values['ar']!;

  /// Look up a key, with optional `{placeholder}` substitution.
  String t(String key, {Map<String, String>? args}) {
    var value = _map[key] ?? AppStrings.values['ar']![key] ?? key;
    if (args != null) {
      args.forEach((k, v) => value = value.replaceAll('{$k}', v));
    }
    return value;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['ar', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// Convenience: `context.l10n.t('key')`.
extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String tr(String key, {Map<String, String>? args}) => l10n.t(key, args: args);
}
