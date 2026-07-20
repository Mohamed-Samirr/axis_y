import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injector.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/commerce.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/repositories/catalog_repository.dart';
import '../../../core/repositories/tryon_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../../cart_checkout/cubit/cart_cubit.dart';
import '../cubit/tryon_cubit.dart';

class TryOnScreen extends StatelessWidget {
  final String productId;
  const TryOnScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TryOnCubit(sl<CatalogRepository>(), sl<TryOnRepository>(), sl<AuthRepository>())..load(productId),
      child: const _TryOnBody(),
    );
  }
}

class _TryOnBody extends StatelessWidget {
  const _TryOnBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1526),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(context.tr('tryon_title'), style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('save_screenshot')))),
          ),
        ],
      ),
      body: BlocBuilder<TryOnCubit, TryOnState>(
        builder: (context, state) {
          return switch (state) {
            TryOnLoading() => const Center(child: CircularProgressIndicator(color: Colors.white)),
            TryOnError(:final message) => ErrorView(message: message),
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
    final rows = context.read<TryOnCubit>().fitRows();
    showModalBottomSheet(
      context: context,
      builder: (_) => _FitSheet(rows: rows),
    );
  }

  void _addToCart(BuildContext context) {
    context.read<CartCubit>().add(CartItem(product: state.product, color: state.color, size: state.size));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('added_to_cart'))));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Center(child: _Mannequin(color: Color(state.color.hex))),
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(context.tr('tryon_hint'), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
        // Size compare button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38)),
            onPressed: () => _showFit(context),
            icon: const Icon(Icons.straighten),
            label: Text('${context.tr('size_compare')} (${state.size})'),
          ),
        ),
        const SizedBox(height: 12),
        // Color circles
        SizedBox(
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
                    border: Border.all(color: selected ? AppColors.gold : Colors.white24, width: selected ? 3 : 1),
                  ),
                ),
              );
            },
          ),
        ),
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

/// Placeholder 3D mannequin: drag horizontally to rotate, pinch to zoom.
/// The real AI engine replaces this behind [TryOnRepository].
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

class _FitSheet extends StatelessWidget {
  final List<FitRow> rows;
  const _FitSheet({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('size_compare'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(flex: 2, child: SizedBox()),
              Expanded(child: Text(context.tr('your_size'), style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
              Expanded(child: Text(context.tr('product_size'), style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
              Expanded(child: Text(context.tr('verdict'), style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
            ],
          ),
          const Divider(),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: Text(context.tr(r.labelKey), style: const TextStyle(fontWeight: FontWeight.w600))),
                    Expanded(child: Text('${r.yourValue}', textAlign: TextAlign.center)),
                    Expanded(child: Text('${r.productValue}', textAlign: TextAlign.center)),
                    Expanded(
                      child: Text(
                        r.ok ? '✔ ${context.tr('fit_ok')}' : '⚠ ${context.tr('fit_tight')}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: r.ok ? AppColors.success : AppColors.warning, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
