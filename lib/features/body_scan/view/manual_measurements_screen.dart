import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/local_store.dart';
import '../../../core/di/injector.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/user.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../models/scan_input.dart';

/// Lets the user type in their own measurements instead of running the
/// camera scan. The two body photos here are a purely optional, local-only
/// aid — they are never uploaded or analyzed (privacy rule F4 still holds:
/// the app never sends or persists body photos to a server).
class ManualMeasurementsScreen extends StatefulWidget {
  final double? initialHeightCm;
  const ManualMeasurementsScreen({super.key, this.initialHeightCm});

  @override
  State<ManualMeasurementsScreen> createState() => _ManualMeasurementsScreenState();
}

class _ManualMeasurementsScreenState extends State<ManualMeasurementsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _height = TextEditingController(text: widget.initialHeightCm?.toStringAsFixed(0) ?? '');
  final _weight = TextEditingController();
  final _chest = TextEditingController();
  final _waist = TextEditingController();
  final _hips = TextEditingController();
  final _shoulder = TextEditingController();
  final _inseam = TextEditingController();

  File? _front;
  File? _side;
  bool _saving = false;

  @override
  void dispose() {
    // The files are a local-only aid, never uploaded — same deletion rule as
    // the camera scan flow (F4): they must not outlive this screen.
    _deletePhotos();
    _height.dispose();
    _weight.dispose();
    _chest.dispose();
    _waist.dispose();
    _hips.dispose();
    _shoulder.dispose();
    _inseam.dispose();
    super.dispose();
  }

  Future<void> _deletePhotos() async {
    for (final f in [_front, _side]) {
      if (f == null) continue;
      try {
        if (await f.exists()) await f.delete();
      } catch (_) {
        // Best effort.
      }
    }
  }

  Future<void> _capturePhotos() async {
    final heightCm = double.tryParse(_height.text.trim()) ?? 0;
    final result = await context.push<ScanInput>(
      Routes.scanCamera,
      extra: ScanInput(heightCm: heightCm, manualPhotoCapture: true),
    );
    if (result == null || !mounted) return;
    // Replace, not accumulate: a retake must discard the previous pair.
    await _deletePhotos();
    setState(() {
      _front = result.front;
      _side = result.side;
    });
  }

  String? _validateRequired(String? value) {
    final v = double.tryParse((value ?? '').trim());
    if (v == null || v <= 0) return context.tr('measurement_invalid');
    return null;
  }

  String? _validateOptional(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return null;
    final v = double.tryParse(trimmed);
    if (v == null || v <= 0) return context.tr('measurement_invalid');
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = sl<AuthRepository>();
    final user = auth.currentUser;
    if (user == null) return;

    setState(() => _saving = true);
    final measurements = Measurements(
      chest: double.parse(_chest.text.trim()).round(),
      waist: double.parse(_waist.text.trim()).round(),
      hips: double.parse(_hips.text.trim()).round(),
      height: double.parse(_height.text.trim()).round(),
      weight: double.parse(_weight.text.trim()).round(),
      shoulderCm: double.tryParse(_shoulder.text.trim()),
      inseamCm: double.tryParse(_inseam.text.trim()),
    );
    await auth.saveUser(user.copyWith(measurements: measurements));
    await _deletePhotos();
    _front = null;
    _side = null;
    if (!mounted) return;

    final hasPrefs = sl<LocalStore>().getJson(StoreKeys.preferences) != null;
    if (hasPrefs) {
      context.go(Routes.profile);
    } else {
      context.go(Routes.preferences);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhotos = _front != null && _side != null;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('manual_entry_title'))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(context.tr('manual_entry_sub'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 20),
            _numberField(controller: _height, labelKey: 'height', validator: _validateRequired),
            const SizedBox(height: 14),
            _numberField(controller: _weight, labelKey: 'weight', unitKey: 'kg', validator: _validateRequired),
            const SizedBox(height: 14),
            _numberField(controller: _chest, labelKey: 'chest', validator: _validateRequired),
            const SizedBox(height: 14),
            _numberField(controller: _waist, labelKey: 'waist', validator: _validateRequired),
            const SizedBox(height: 14),
            _numberField(controller: _hips, labelKey: 'hips', validator: _validateRequired),
            const SizedBox(height: 14),
            _numberField(controller: _shoulder, labelKey: 'shoulder', optional: true, validator: _validateOptional),
            const SizedBox(height: 14),
            _numberField(controller: _inseam, labelKey: 'inseam', optional: true, validator: _validateOptional),
            const SizedBox(height: 28),
            Text(context.tr('manual_photos_section'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(context.tr('manual_photos_hint'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _capturePhotos,
              icon: Icon(hasPhotos ? Icons.check_circle : Icons.camera_alt_outlined),
              label: Text(context.tr(hasPhotos ? 'retake_photos' : 'add_photos')),
            ),
            if (hasPhotos) ...[
              const SizedBox(height: 8),
              Text(context.tr('photos_added'), style: const TextStyle(color: AppColors.success, fontSize: 13)),
            ],
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(context.tr('confirm_save')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String labelKey,
    String? unitKey,
    bool optional = false,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: InputDecoration(
        labelText: optional
            ? '${context.tr(labelKey)} (${context.tr('optional_field')})'
            : context.tr(labelKey),
        suffixText: unitKey != null ? context.tr(unitKey) : context.tr('cm'),
      ),
      validator: validator,
    );
  }
}
