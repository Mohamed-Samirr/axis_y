import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/fit.dart';
import '../theme/app_colors.dart';

/// Shared rendering of a backend fit verdict, so the product page and the
/// try-on screen never disagree about what "TOO_TIGHT" looks like.

Color verdictColor(FitVerdict verdict) => switch (verdict.tone) {
      FitTone.good => AppColors.success,
      FitTone.caution => AppColors.warning,
      FitTone.bad => AppColors.danger,
    };

IconData verdictIcon(FitVerdict verdict) => switch (verdict.tone) {
      FitTone.good => Icons.check_circle_outline,
      FitTone.caution => Icons.info_outline,
      FitTone.bad => Icons.warning_amber_rounded,
    };

class VerdictChip extends StatelessWidget {
  final FitVerdict verdict;
  final bool dense;
  const VerdictChip({super.key, required this.verdict, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final color = verdictColor(verdict);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 2 : 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        context.tr(verdict.key),
        style: TextStyle(color: color, fontSize: dense ? 11 : 13, fontWeight: FontWeight.bold),
      ),
    );
  }
}
