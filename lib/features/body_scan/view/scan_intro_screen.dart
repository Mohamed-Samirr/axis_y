import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';

class ScanIntroScreen extends StatelessWidget {
  const ScanIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.08), shape: BoxShape.circle),
              child: const Icon(Icons.accessibility_new, size: 90, color: AppColors.navy),
            ),
            const SizedBox(height: 32),
            Text(context.tr('scan_intro_title'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(context.tr('scan_intro_sub'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 15), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, color: AppColors.success, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(context.tr('scan_privacy'), style: const TextStyle(fontSize: 13, color: AppColors.success))),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push(Routes.scanCamera),
                child: Text(context.tr('scan_start')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
