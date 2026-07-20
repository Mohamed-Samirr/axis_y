import 'package:flutter/material.dart';

/// AXIS Y brand palette.
abstract class AppColors {
  static const Color navy = Color(0xFF1B2A4A); // primary brand
  static const Color navyLight = Color(0xFF2E4269);
  static const Color gold = Color(0xFFC9A24B);

  static const Color background = Color(0xFFF6F7F9);
  static const Color surface = Colors.white;
  static const Color card = Colors.white;

  static const Color textPrimary = Color(0xFF1B2432);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color divider = Color(0xFFE5E7EB);

  static const Color success = Color(0xFF2E9E5B);
  static const Color warning = Color(0xFFE0A800);
  static const Color danger = Color(0xFFDC3545);
  static const Color price = Color(0xFFDC3545);

  // Loyalty tiers
  static const Color tierRegular = Color(0xFF3B82F6);
  static const Color tierSilver = Color(0xFF9CA3AF);
  static const Color tierGold = Color(0xFFC9A24B);
  static const Color tierPlatinum = Color(0xFF6D5BD0);

  // Dark
  static const Color darkBackground = Color(0xFF10151F);
  static const Color darkSurface = Color(0xFF1A2130);
}
