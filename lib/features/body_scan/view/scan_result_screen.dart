import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../../core/config/app_config.dart';
import '../../../core/data/local_store.dart';
import '../../../core/di/injector.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/repositories/body_scan_repository.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/model_storage.dart';
import '../../../core/widgets/state_views.dart';
import '../cubit/body_scan_cubit.dart';
import '../models/scan_input.dart';

class ScanResultScreen extends StatelessWidget {
  final ScanInput input;
  const ScanResultScreen({super.key, required this.input});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BodyScanCubit(sl<BodyScanRepository>(), sl<AuthRepository>())..analyze(input),
      child: _ScanResultBody(input: input),
    );
  }
}

class _ScanResultBody extends StatelessWidget {
  final ScanInput input;
  const _ScanResultBody({required this.input});

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
          if (state.isBusy) return _ProgressView(status: state.status);
          if (state.status == ScanStatus.error || state.measurements == null) {
            return ErrorView(
              message: context.tr(state.error ?? 'error_generic'),
              onRetry: () => context.read<BodyScanCubit>().analyze(input),
            );
          }
          return _ResultView(state: state, onConfirm: () => _confirm(context));
        },
      ),
    );
  }
}

/// Staged copy — a single undifferentiated spinner would read as a hang across
/// a 30s+ pipeline.
class _ProgressView extends StatelessWidget {
  final ScanStatus status;
  const _ProgressView({required this.status});

  @override
  Widget build(BuildContext context) {
    final key = switch (status) {
      ScanStatus.uploading => 'scan_uploading',
      ScanStatus.buildingModel => 'scan_building_model',
      _ => 'analyzing',
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.navy),
          const SizedBox(height: 20),
          Text(context.tr(key), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              context.tr('scan_takes_time'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final BodyScanState state;
  final VoidCallback onConfirm;
  const _ResultView({required this.state, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final m = state.measurements!;
    final lowConfidence = m.confidence != null && m.confidence! < AppConfig.lowConfidenceThreshold;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (m.modelPath != null) _BodyModelViewer(relativePath: m.modelPath!),
              if (m.modelPath == null) ...[
                const SizedBox(height: 8),
                const Center(child: Icon(Icons.check_circle, color: AppColors.success, size: 64)),
                const SizedBox(height: 16),
              ],
              if (lowConfidence) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(context.tr('scan_low_confidence'), style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _row(context, 'height', '${m.height} سم'),
              _row(context, 'weight', '${m.weight} كجم'),
              _row(context, 'chest', '${m.chest} سم'),
              _row(context, 'waist', '${m.waist} سم'),
              _row(context, 'hips', '${m.hips} سم'),
              if (m.shoulderCm != null) _row(context, 'shoulder', '${m.shoulderCm!.toStringAsFixed(1)} سم'),
              if (m.inseamCm != null) _row(context, 'inseam', '${m.inseamCm!.toStringAsFixed(1)} سم'),
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
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 16 + MediaQuery.of(context).padding.bottom),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: onConfirm, child: Text(context.tr('confirm_save'))),
          ),
        ),
      ],
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

/// Renders the scanned `.glb` body mesh. This is the body shape only — no
/// garment — so it lives here as proof the measurements are real, rather than
/// in the try-on screen, until the backend can drape a garment.
class _BodyModelViewer extends StatelessWidget {
  final String relativePath;
  const _BodyModelViewer({required this.relativePath});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: ModelStorage.resolve(relativePath),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator(color: AppColors.navy)));
        }
        final path = snapshot.data;
        if (path == null) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('body_model_3d'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 320,
                child: ModelViewer(
                  src: 'file://$path',
                  alt: context.tr('body_model_3d'),
                  cameraControls: true, // drag = rotate, pinch = zoom
                  autoRotate: false,
                  disableZoom: false,
                  backgroundColor: const Color(0xFF0E1526),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}
