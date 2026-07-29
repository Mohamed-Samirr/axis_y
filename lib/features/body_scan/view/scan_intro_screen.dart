import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../models/scan_input.dart';

/// Explains the scan and collects the user's height — the API cannot compute
/// anything without it, since height is the pixel→cm reference scale.
class ScanIntroScreen extends StatefulWidget {
  const ScanIntroScreen({super.key});

  @override
  State<ScanIntroScreen> createState() => _ScanIntroScreenState();
}

class _ScanIntroScreenState extends State<ScanIntroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _height = TextEditingController();
  final _weight = TextEditingController();

  @override
  void dispose() {
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  double? get _weightKg => double.tryParse(_weight.text.trim());

  void _start() {
    if (!_formKey.currentState!.validate()) return;
    final heightCm = double.parse(_height.text.trim());
    context.push(Routes.scanCamera, extra: ScanInput(heightCm: heightCm, weightKg: _weightKg));
  }

  /// Bypasses the camera + AI pipeline entirely: the user types their own
  /// measurements on the next screen instead of being scanned. Whatever was
  /// already typed here is carried over so it isn't asked for twice.
  void _skipToManual() {
    final heightCm = double.tryParse(_height.text.trim());
    context.push(
      Routes.scanManual,
      extra: heightCm == null ? null : ScanInput(heightCm: heightCm, weightKg: _weightKg),
    );
  }

  /// Validated client-side so the user gets an instant error instead of a
  /// 15-second round trip ending in a 422.
  String? _validateHeight(String? value) {
    final h = double.tryParse((value ?? '').trim());
    if (h == null || h < 100 || h > 250) return context.tr('height_invalid');
    return null;
  }

  /// Optional field: empty passes, but a typed value still has to be sane.
  String? _validateWeight(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return null;
    final w = double.tryParse(trimmed);
    if (w == null || w < 30 || w > 300) return context.tr('weight_invalid');
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.08), shape: BoxShape.circle),
                child: const Icon(Icons.accessibility_new, size: 80, color: AppColors.navy),
              ),
            ),
            const SizedBox(height: 28),
            Text(context.tr('scan_intro_title'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(context.tr('scan_intro_sub'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 15), textAlign: TextAlign.center),
            const SizedBox(height: 28),
            TextFormField(
              controller: _height,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: context.tr('enter_height'),
                suffixText: 'cm',
                prefixIcon: const Icon(Icons.height),
              ),
              validator: _validateHeight,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _weight,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: '${context.tr('enter_weight')} (${context.tr('optional_field')})',
                suffixText: context.tr('kg'),
                prefixIcon: const Icon(Icons.monitor_weight_outlined),
              ),
              validator: _validateWeight,
            ),
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
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.schedule, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(child: Text(context.tr('scan_takes_time'), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _start, child: Text(context.tr('scan_start'))),
            const SizedBox(height: 12),
            TextButton(onPressed: _skipToManual, child: Text(context.tr('skip_scan_manual'))),
          ],
        ),
      ),
    );
  }
}
