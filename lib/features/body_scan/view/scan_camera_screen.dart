import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';

/// Mock camera overlay with guide lines. Captures a front then a side "photo",
/// then routes to analysis. No real camera / no image is stored (privacy).
class ScanCameraScreen extends StatefulWidget {
  const ScanCameraScreen({super.key});

  @override
  State<ScanCameraScreen> createState() => _ScanCameraScreenState();
}

class _ScanCameraScreenState extends State<ScanCameraScreen> {
  int _step = 0; // 0 = front, 1 = side

  void _capture() {
    if (_step == 0) {
      setState(() => _step = 1);
    } else {
      context.pushReplacement(Routes.scanResult);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _step == 0 ? context.tr('scan_front') : context.tr('scan_side');
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Mock camera viewfinder.
            Positioned.fill(
              child: CustomPaint(painter: _BodyGuidePainter()),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => context.pop(),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                  child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(12)),
                child: Text(context.tr('scan_hint'), style: const TextStyle(color: Colors.white)),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: GestureDetector(
                  onTap: _capture,
                  child: Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 130,
              left: 0,
              right: 0,
              child: Center(
                child: Text('${_step + 1} / 2', style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BodyGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final cx = size.width / 2;
    final top = size.height * 0.14;
    final bottom = size.height * 0.86;
    final h = bottom - top;

    // Head
    canvas.drawCircle(Offset(cx, top + h * 0.08), h * 0.07, paint);
    // Body outline
    final body = Path()
      ..moveTo(cx - h * 0.12, top + h * 0.2)
      ..lineTo(cx + h * 0.12, top + h * 0.2)
      ..lineTo(cx + h * 0.09, bottom)
      ..lineTo(cx - h * 0.09, bottom)
      ..close();
    canvas.drawPath(body, paint);
    // Arms
    canvas.drawLine(Offset(cx - h * 0.12, top + h * 0.22), Offset(cx - h * 0.2, top + h * 0.55), paint);
    canvas.drawLine(Offset(cx + h * 0.12, top + h * 0.22), Offset(cx + h * 0.2, top + h * 0.55), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
