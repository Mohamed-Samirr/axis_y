import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../models/scan_input.dart';

/// Real capture of the two body photos, with the guide overlay drawn on top of
/// the live preview — the overlay is what makes users frame themselves head to
/// feet, which the backend's scale computation requires (it needs the nose and
/// both heels visible).
class ScanCameraScreen extends StatefulWidget {
  final ScanInput input;
  const ScanCameraScreen({super.key, required this.input});

  @override
  State<ScanCameraScreen> createState() => _ScanCameraScreenState();
}

class _ScanCameraScreenState extends State<ScanCameraScreen> {
  CameraController? _controller;
  int _step = 0; // 0 = front, 1 = side
  File? _front;
  bool _initializing = true;
  bool _capturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _error = 'camera_permission';
          _initializing = false;
        });
        return;
      }
      // Rear camera: a selfie camera cannot frame a full standing body.
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      // `high` (720p) keeps uploads small; below it, segmentation quality drops.
      final controller = CameraController(camera, ResolutionPreset.high, enableAudio: false);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } on CameraException {
      // Covers permission denial as well as hardware failures.
      if (mounted) {
        setState(() {
          _error = 'camera_permission';
          _initializing = false;
        });
      }
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      // takePicture() writes to a temp dir; that file is the only copy and the
      // Cubit deletes it once the scan finishes.
      final shot = await controller.takePicture();
      final file = File(shot.path);
      if (!mounted) return;
      if (_step == 0) {
        setState(() {
          _front = file;
          _step = 1;
          _capturing = false;
        });
      } else {
        context.pushReplacement(
          Routes.scanResult,
          extra: widget.input.copyWith(front: _front, side: file),
        );
      }
    } on CameraException {
      if (mounted) {
        setState(() => _capturing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('error_generic'))));
      }
    }
  }

  @override
  void dispose() {
    // The preview keeps the camera hardware open until disposed.
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = _step == 0 ? context.tr('scan_front') : context.tr('scan_side');
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _error != null
            ? _PermissionRationale(onRetry: () {
                setState(() {
                  _error = null;
                  _initializing = true;
                });
                _initCamera();
              })
            : _initializing
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : Stack(
                    children: [
                      Positioned.fill(child: CameraPreview(_controller!)),
                      const Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _BodyGuidePainter()))),
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
                              child: _capturing
                                  ? const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : Container(
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

/// Rationale shown when camera access is unavailable or denied (F4).
class _PermissionRationale extends StatelessWidget {
  final VoidCallback onRetry;
  const _PermissionRationale({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.no_photography_outlined, color: Colors.white70, size: 72),
          const SizedBox(height: 20),
          Text(
            context.tr('camera_permission'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: onRetry, child: Text(context.tr('retry'))),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => context.pop(),
            child: Text(context.tr('skip'), style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}

class _BodyGuidePainter extends CustomPainter {
  const _BodyGuidePainter();

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
