import 'package:flutter/material.dart';

import '../../../core/data/mock_seed.dart';
import '../../../core/di/injector.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/user.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/theme/app_colors.dart';

class LoyaltyScreen extends StatelessWidget {
  const LoyaltyScreen({super.key});

  Color _tierColor(LoyaltyTier t) => switch (t) {
        LoyaltyTier.regular => AppColors.tierRegular,
        LoyaltyTier.silver => AppColors.tierSilver,
        LoyaltyTier.gold => AppColors.tierGold,
        LoyaltyTier.platinum => AppColors.tierPlatinum,
      };

  @override
  Widget build(BuildContext context) {
    final user = sl<AuthRepository>().currentUser;
    final points = user?.points ?? 0;
    final tier = user?.tier ?? LoyaltyTier.regular;
    final nextTier = LoyaltyTier.values.firstWhere((t) => t.threshold > points, orElse: () => LoyaltyTier.platinum);
    final progress = nextTier.threshold == tier.threshold
        ? 1.0
        : (points - tier.threshold) / (nextTier.threshold - tier.threshold);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('loyalty'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.navy, _tierColor(tier)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.workspace_premium, color: Colors.white),
                    const SizedBox(width: 8),
                    Text('${context.tr('tier')}: ${context.tr(tier.key)}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                Text('$points', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                Text(context.tr('points'), style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0, 1),
                    minHeight: 8,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                const SizedBox(height: 6),
                if (nextTier.threshold > points)
                  Text('${nextTier.threshold - points} ${context.tr('points')} → ${context.tr(nextTier.key)}', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(context.tr('how_to_earn'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...MockSeed.earnRules.map((r) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.stars, color: AppColors.gold),
                title: Text(r.$1),
                trailing: Text('+${r.$2}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
              )),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.redeem, color: AppColors.navy),
                const SizedBox(width: 10),
                Expanded(child: Text('${context.tr('redeem')}: 100 ${context.tr('points')} = 10 ${context.tr('currency')}')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
