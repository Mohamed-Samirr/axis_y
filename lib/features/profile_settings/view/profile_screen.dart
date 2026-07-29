import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injector.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/user.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = sl<AuthRepository>();
    final user = auth.currentUser;
    final m = user?.measurements;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(context.tr('profile')),
        actions: [
          IconButton(onPressed: () => context.push(Routes.settings), icon: const Icon(Icons.settings_outlined)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: AppColors.navy.withValues(alpha: 0.1),
                child: Text(
                  (user?.name.isNotEmpty ?? false) ? user!.name[0] : 'A',
                  style: const TextStyle(fontSize: 28, color: AppColors.navy, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.name ?? 'AXIS', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(user?.phoneOrEmail ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              IconButton(onPressed: () => _snack(context, 'edit'), icon: const Icon(Icons.edit_outlined)),
            ],
          ),
          const SizedBox(height: 16),
          // Points + tier card
          GestureDetector(
            onTap: () => context.push(Routes.loyalty),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  const Icon(Icons.workspace_premium, color: AppColors.gold, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${user?.points ?? 0} ${context.tr('points')}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('${context.tr('tier')}: ${context.tr((user?.tier.key) ?? 'tier_regular')}', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_left, color: Colors.white),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Measurements
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.divider)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.straighten, color: AppColors.navy),
                    const SizedBox(width: 8),
                    Text(context.tr('measurements'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Spacer(),
                    TextButton(onPressed: () => context.push(Routes.scanIntro), child: Text(context.tr('update_scan'))),
                  ],
                ),
                if (m != null)
                  Text(
                    '${context.tr('height')} ${m.height} • ${context.tr('chest')} ${m.chest} • ${context.tr('waist')} ${m.waist} • ${context.tr('hips')} ${m.hips}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  )
                else
                  Text(context.tr('scan_intro_sub'), style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Only when a mesh actually exists — the screen would otherwise open
          // straight onto its "no model" state.
          if (m?.modelPath != null)
            _link(context, Icons.view_in_ar_outlined, context.tr('body_model_3d'), () => context.push(Routes.avatar)),
          _link(context, Icons.receipt_long_outlined, context.tr('my_orders'), () => context.push(Routes.orders)),
          // Pushed, not `go`: the wishlist is no longer a tab while the 3D model
          // holds that slot, so it needs a back button out.
          _link(context, Icons.favorite_border, context.tr('wishlist'), () => context.push(Routes.wishlist)),
          _link(context, Icons.compare_arrows, context.tr('compare_title'), () => context.push(Routes.compare)),
          _link(context, Icons.auto_awesome_outlined, context.tr('assistant'), () => context.push(Routes.assistant)),
          _link(context, Icons.location_on_outlined, context.tr('saved_addresses'), () => _snack(context, 'saved_addresses')),
          _link(context, Icons.storefront_outlined, context.tr('register_store'), () => context.push(Routes.registerStore)),
          _link(context, Icons.settings_outlined, context.tr('settings'), () => context.push(Routes.settings)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
            onPressed: () async {
              await auth.logout();
              if (context.mounted) context.go(Routes.login);
            },
            icon: const Icon(Icons.logout),
            label: Text(context.tr('logout')),
          ),
        ],
      ),
    );
  }

  Widget _link(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.navy),
      title: Text(title),
      trailing: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }

  void _snack(BuildContext context, String key) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr(key))));
}
