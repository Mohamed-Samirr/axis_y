import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/local_store.dart';
import '../../../core/di/injector.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/repositories/body_scan_repository.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../cubit/body_scan_cubit.dart';

class ScanResultScreen extends StatelessWidget {
  const ScanResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BodyScanCubit(sl<BodyScanRepository>(), sl<AuthRepository>())..analyze(),
      child: const _ScanResultBody(),
    );
  }
}

class _ScanResultBody extends StatelessWidget {
  const _ScanResultBody();

  Future<void> _confirm(BuildContext context) async {
    await context.read<BodyScanCubit>().confirmAndSave();
    if (!context.mounted) return;
    final hasPrefs = sl<LocalStore>().getJson(StoreKeys.preferences) != null;
    if (hasPrefs) {
      // Re-scan from profile: just go back.
      context.go(Routes.profile);
    } else {
      context.go(Routes.preferences);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('measurements'))),
      body: BlocBuilder<BodyScanCubit, BodyScanState>(
        builder: (context, state) {
          if (state.status == ScanStatus.analyzing || state.status == ScanStatus.idle) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.navy),
                  const SizedBox(height: 20),
                  Text(context.tr('analyzing'), style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }
          final m = state.measurements!;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 8),
                const Icon(Icons.check_circle, color: AppColors.success, size: 64),
                const SizedBox(height: 16),
                _row(context, 'height', '${m.height} سم'),
                _row(context, 'weight', '${m.weight} كجم'),
                _row(context, 'chest', '${m.chest} سم'),
                _row(context, 'waist', '${m.waist} سم'),
                _row(context, 'hips', '${m.hips} سم'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.straighten, color: AppColors.navy),
                      const SizedBox(width: 10),
                      Text('${context.tr('your_size')}: ${m.recommendedSize}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(onPressed: () => _confirm(context), child: Text(context.tr('confirm_save'))),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(context.tr(key), style: const TextStyle(fontSize: 16, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
