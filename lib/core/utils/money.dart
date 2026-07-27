import '../data/local_store.dart';
import '../di/injector.dart';
import '../localization/app_strings.dart';

/// Formats an EGP amount with the currency symbol in the current locale,
/// e.g. `499 ج.م` (Arabic) or `499 EGP` (English).
String formatEgp(num amount) {
  final rounded = amount % 1 == 0 ? amount.toInt().toString() : amount.toStringAsFixed(2);
  final localeCode = sl<LocalStore>().getString(StoreKeys.locale) ?? 'ar';
  final symbol = AppStrings.values[localeCode]?['currency'] ?? AppStrings.values['ar']!['currency']!;
  return '$rounded $symbol';
}
