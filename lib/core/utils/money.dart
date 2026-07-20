import '../config/app_config.dart';

/// Formats an EGP amount with the currency symbol, e.g. `499 ج.م`.
String formatEgp(num amount) {
  final rounded = amount % 1 == 0 ? amount.toInt().toString() : amount.toStringAsFixed(2);
  return '$rounded ${AppConfig.currencySymbol}';
}
