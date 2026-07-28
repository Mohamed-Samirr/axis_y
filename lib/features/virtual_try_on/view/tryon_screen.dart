import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../../core/di/injector.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/commerce.dart';
import '../../../core/models/fit.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/repositories/catalog_repository.dart';
import '../../../core/repositories/tryon_repository.dart';
import '../../../core/router/routes.dart';
import '../../../core/services/glb_cache.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/verdict_view.dart';
import '../../cart_checkout/cubit/cart_cubit.dart';
import '../cubit/tryon_cubit.dart';

const _sceneBackground = Color(0xFF0E1526);

class TryOnScreen extends StatelessWidget {
  final String productId;
  const TryOnScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TryOnCubit(
        sl<CatalogRepository>(),
        sl<TryOnRepository>(),
        sl<AuthRepository>(),
        sl<SessionService>(),
        sl<GlbCache>(),
      )..load(productId),
      child: const _TryOnBody(),
    );
  }
}

class _TryOnBody extends StatelessWidget {
  const _TryOnBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _sceneBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(context.tr('tryon_title'), style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            onPressed: () => ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(context.tr('save_screenshot')))),
          ),
        ],
      ),
      body: BlocBuilder<TryOnCubit, TryOnState>(
        builder: (context, state) {
          return switch (state) {
            TryOnLoading() => const Center(child: CircularProgressIndicator(color: Colors.white)),
            TryOnError(:final message) => ErrorView(message: context.tr(message)),
            TryOnReady() => _Scene(state: state),
          };
        },
      ),
    );
  }
}

class _Scene extends StatelessWidget {
  final TryOnReady state;
  const _Scene({required this.state});

  void _showFit(BuildContext context) {
    final fit = state.fit;
    if (fit == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FitSheet(fit: fit, size: state.size),
    );
  }

  void _addToCart(BuildContext context) {
    context.read<CartCubit>().add(
          CartItem(product: state.product, color: state.color, size: state.size),
        );
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.tr('added_to_cart'))));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: state.meshPath != null
                    ? _MeshViewer(path: state.meshPath!)
                    : Center(child: _Mannequin(color: Color(state.color.hex))),
              ),
              // The morph runs server-side; the previous mesh stays visible
              // under the veil so a size toggle never blanks the screen.
              if (state.morphing) const Positioned.fill(child: _MorphingVeil()),
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    context.tr('tryon_hint'),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (state.needsScan) const _NeedsScanBanner(),
        if (state.fitError != null && !state.needsScan)
          _FitErrorBanner(messageKey: state.fitError!),
        if (state.fit != null) _VerdictBar(fit: state.fit!, onTap: () => _showFit(context)),
        const SizedBox(height: 12),
        _SizeSelector(state: state),
        const SizedBox(height: 12),
        _ColorSelector(state: state),
        const SizedBox(height: 12),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + MediaQuery.of(context).padding.bottom),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _addToCart(context),
              icon: const Icon(Icons.shopping_bag_outlined),
              label: Text(context.tr('add_to_cart')),
            ),
          ),
        ),
      ],
    );
  }
}

/// Renders the morphed `.glb` handed back by `POST /try-on`.
///
/// Keyed on the file path so a size toggle tears the old viewer down instead of
/// re-using it — the webview holds the whole mesh in memory, and leaking one per
/// size is how low-end Androids OOM (guide §11).
class _MeshViewer extends StatelessWidget {
  final String path;
  const _MeshViewer({required this.path});

  @override
  Widget build(BuildContext context) {
    return ModelViewer(
      key: ValueKey(path),
      src: 'file://$path',
      alt: context.tr('tryon_title'),
      cameraControls: true, // drag = rotate, pinch = zoom
      autoRotate: false,
      disableZoom: false,
      backgroundColor: _sceneBackground,
    );
  }
}

class _MorphingVeil extends StatelessWidget {
  const _MorphingVeil();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _sceneBackground.withValues(alpha: 0.55),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 14),
            Text(
              context.tr('tryon_morphing'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Size toggling (guide §5.6): each tap re-runs the try-on for that size.
class _SizeSelector extends StatelessWidget {
  final TryOnReady state;
  const _SizeSelector({required this.state});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: state.sizes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final size = state.sizes[i];
          final selected = size.label == state.size;
          return GestureDetector(
            onTap: size.available && !state.morphing
                ? () => context.read<TryOnCubit>().selectSize(size.label)
                : null,
            child: Container(
              width: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.gold : Colors.white10,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: selected ? AppColors.gold : Colors.white24),
              ),
              child: Text(
                size.label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: selected
                      ? _sceneBackground
                      : (size.available ? Colors.white : Colors.white38),
                  decoration: size.available ? null : TextDecoration.lineThrough,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ColorSelector extends StatelessWidget {
  final TryOnReady state;
  const _ColorSelector({required this.state});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: state.product.colors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final c = state.product.colors[i];
          final selected = i == state.colorIndex;
          return GestureDetector(
            onTap: () => context.read<TryOnCubit>().selectColor(i),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color(c.hex),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.gold : Colors.white24,
                  width: selected ? 3 : 1,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The headline verdict for the size on screen. Tapping opens the per-region
/// breakdown the `FitEngine` returned.
class _VerdictBar extends StatelessWidget {
  final FitResult fit;
  final VoidCallback onTap;
  const _VerdictBar({required this.fit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = verdictColor(fit.overallVerdict);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Icon(verdictIcon(fit.overallVerdict), color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${context.tr(fit.overallVerdict.key)} · ${fit.sizeLabel ?? ''}',
                      style: TextStyle(color: color, fontWeight: FontWeight.bold),
                    ),
                    if (fit.hasConstraintWarnings)
                      Text(
                        context.tr('fit_constraint_warning'),
                        style: const TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                  ],
                ),
              ),
              Text(
                context.tr('fit_details'),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const Icon(Icons.chevron_right, color: Colors.white70, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _NeedsScanBanner extends StatelessWidget {
  const _NeedsScanBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.straighten, color: AppColors.gold, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.tr('tryon_needs_scan'),
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: () => context.push(Routes.scanIntro),
              child: Text(context.tr('scan_start')),
            ),
          ],
        ),
      ),
    );
  }
}

class _FitErrorBanner extends StatelessWidget {
  final String messageKey;
  const _FitErrorBanner({required this.messageKey});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.tr(messageKey),
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: () => context.read<TryOnCubit>().retry(),
              child: Text(context.tr('retry')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder mannequin, shown when the backend returned no mesh (offline mock
/// or a morph that failed). Drag to rotate, pinch to zoom.
class _Mannequin extends StatefulWidget {
  final Color color;
  const _Mannequin({required this.color});

  @override
  State<_Mannequin> createState() => _MannequinState();
}

class _MannequinState extends State<_Mannequin> {
  double _rotation = 0;
  double _scale = 1;
  double _baseScale = 1;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: (_) => _baseScale = _scale,
      onScaleUpdate: (details) {
        setState(() {
          _rotation += details.focalPointDelta.dx * 0.01;
          _scale = (_baseScale * details.scale).clamp(0.7, 2.0);
        });
      },
      child: Transform.scale(
        scale: _scale,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(_rotation),
          child: CustomPaint(
            size: const Size(220, 460),
            painter: _MannequinPainter(garment: widget.color, angle: _rotation),
          ),
        ),
      ),
    );
  }
}

class _MannequinPainter extends CustomPainter {
  final Color garment;
  final double angle;
  _MannequinPainter({required this.garment, required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final bodyPaint = Paint()..color = const Color(0xFFB8842A).withValues(alpha: 0.9);
    final garmentPaint = Paint()..color = garment;
    final w = size.width;
    final h = size.height;
    // subtle shading based on rotation
    final shade = (math.cos(angle).abs() * 0.15) + 0.85;
    garmentPaint.color = Color.fromRGBO(
      (garment.r * 255 * shade).round().clamp(0, 255),
      (garment.g * 255 * shade).round().clamp(0, 255),
      (garment.b * 255 * shade).round().clamp(0, 255),
      1,
    );

    // Head
    canvas.drawCircle(Offset(w / 2, h * 0.08), h * 0.06, bodyPaint);
    // Neck
    canvas.drawRect(Rect.fromLTWH(w / 2 - w * 0.05, h * 0.13, w * 0.1, h * 0.03), bodyPaint);
    // Torso garment
    final torso = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.28, h * 0.16, w * 0.44, h * 0.34),
      const Radius.circular(24),
    );
    canvas.drawRRect(torso, garmentPaint);
    // Sleeves
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.16, h * 0.18, w * 0.14, h * 0.22), const Radius.circular(16)), garmentPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.70, h * 0.18, w * 0.14, h * 0.22), const Radius.circular(16)), garmentPaint);
    // Legs
    final legPaint = Paint()..color = const Color(0xFF2A3550);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.33, h * 0.50, w * 0.14, h * 0.42), const Radius.circular(14)), legPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.53, h * 0.50, w * 0.14, h * 0.42), const Radius.circular(14)), legPaint);
  }

  @override
  bool shouldRepaint(covariant _MannequinPainter old) => old.garment != garment || old.angle != angle;
}

/// Region-by-region breakdown, straight from `fit_result.regions`.
class _FitSheet extends StatelessWidget {
  final FitResult fit;
  final String size;
  const _FitSheet({required this.fit, required this.size});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${context.tr('size_compare')} · $size',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                VerdictChip(verdict: fit.overallVerdict),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(flex: 2, child: SizedBox()),
                Expanded(child: Text(context.tr('your_size'), style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                Expanded(child: Text(context.tr('product_size'), style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                Expanded(child: Text(context.tr('fit_ease'), style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
              ],
            ),
            const Divider(),
            ...fit.regions.map((r) => _RegionRow(region: r)),
            if (fit.recommendation != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppColors.navy, size: 18),
                    const SizedBox(width: 8),
                    // Server-authored copy: shown as-is, unlike error text.
                    Expanded(child: Text(fit.recommendation!, style: const TextStyle(fontSize: 13))),
                  ],
                ),
              ),
            ],
            if (fit.alternativeSizes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(context.tr('fit_other_sizes'), style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: fit.alternativeSizes
                    .map((a) => Chip(
                          label: Text('${a.sizeLabel} · ${context.tr(a.predictedVerdict.key)}'),
                          labelStyle: TextStyle(fontSize: 12, color: verdictColor(a.predictedVerdict)),
                          backgroundColor: verdictColor(a.predictedVerdict).withValues(alpha: 0.10),
                          side: BorderSide(color: verdictColor(a.predictedVerdict).withValues(alpha: 0.4)),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _RegionRow extends StatelessWidget {
  final FitRegion region;
  const _RegionRow({required this.region});

  @override
  Widget build(BuildContext context) {
    final color = verdictColor(region.verdict);
    final ease = region.easeCm;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(context.tr(region.labelKey), style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Expanded(child: Text(region.bodyCm.toStringAsFixed(1), textAlign: TextAlign.center)),
              Expanded(child: Text(region.garmentCm.toStringAsFixed(1), textAlign: TextAlign.center)),
              Expanded(
                child: Text(
                  '${ease >= 0 ? '+' : ''}${ease.toStringAsFixed(1)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              VerdictChip(verdict: region.verdict, dense: true),
              if (region.constrained) ...[
                const SizedBox(width: 6),
                const Icon(Icons.link, size: 14, color: AppColors.textSecondary),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

