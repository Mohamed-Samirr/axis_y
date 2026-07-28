import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

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
  /// Self-timer options in seconds; 0 means shoot immediately. The user is
  /// alone in front of the camera, so a delay is what lets them step back into
  /// the frame before the shot is taken.
  static const _timerOptions = [0, 3, 10];

  CameraController? _controller;
  int _step = 0; // 0 = front, 1 = side
  File? _front;
  bool _initializing = true;
  bool _capturing = false;
  String? _error;
  int _timerSeconds = 0;
  int _countdown = 0;
  Timer? _countdownTimer;

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
      // Front camera: the user needs to see themselves while framing the pose.
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
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

  void _cycleTimer() {
    _cancelCountdown();
    setState(() {
      _timerSeconds = _timerOptions[(_timerOptions.indexOf(_timerSeconds) + 1) % _timerOptions.length];
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (_countdown != 0) setState(() => _countdown = 0);
  }

  /// Shutter tap: fires straight away with the timer off, otherwise counts down
  /// first. Tapping again mid-countdown cancels it.
  void _onShutter() {
    if (_countdownTimer != null) {
      _cancelCountdown();
      return;
    }
    if (_timerSeconds == 0) {
      _capture();
      return;
    }
    setState(() => _countdown = _timerSeconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_countdown <= 1) {
        _cancelCountdown();
        _capture();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      // takePicture() writes to a temp dir; that file is the only copy and the
      // Cubit deletes it once the scan finishes.
      final shot = await controller.takePicture();
      if (!mounted) return;
      _accept([File(shot.path)]);
    } on CameraException {
      if (mounted) {
        setState(() => _capturing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('error_generic'))));
      }
    }
  }

  /// Alternative to shooting live: pick the two poses from the gallery. Picking
  /// a single image only fills the current step, so the two can be chosen in
  /// separate trips as well.
  Future<void> _pickFromGallery() async {
    if (_capturing) return;
    _cancelCountdown();
    try {
      final picker = ImagePicker();
      // `pickMultiImage` rejects a limit below 2, so the side-only step uses the
      // single-image picker instead.
      // Gallery originals can be 12MP; capping them keeps uploads the same size
      // as the 720p live capture.
      final picked = _step == 0
          ? await picker.pickMultiImage(limit: 2, maxWidth: 720, maxHeight: 1280)
          : [?await picker.pickImage(source: ImageSource.gallery, maxWidth: 720, maxHeight: 1280)];
      if (!mounted || picked.isEmpty) return;
      _accept(picked.take(2).map((x) => File(x.path)).toList());
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('scan_gallery_failed'))));
      }
    }
  }

  /// Consumes one or two images from the current step onwards, advancing the
  /// step or finishing the flow once both poses are in hand.
  void _accept(List<File> files) {
    var front = _front;
    File? side;
    for (final file in files) {
      if (front == null) {
        front = file;
      } else {
        side ??= file;
      }
    }
    if (side == null) {
      setState(() {
        _front = front;
        _step = 1;
        _capturing = false;
      });
      return;
    }
    final result = widget.input.copyWith(front: front, side: side);
    if (widget.input.manualPhotoCapture) {
      // Manual-entry flow: hand the two files back rather than analyzing.
      context.pop(result);
    } else {
      context.pushReplacement(Routes.scanResult, extra: result);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
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
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          tooltip: _timerSeconds == 0
                              ? context.tr('scan_timer_off')
                              : context.tr('scan_timer_on', args: {'s': '$_timerSeconds'}),
                          icon: Icon(
                            _timerSeconds == 0
                                ? Icons.timer_off_outlined
                                : _timerSeconds == 3
                                    ? Icons.timer_3_select
                                    : Icons.timer_10_select,
                            // Gold reads as "armed" against the dark preview.
                            color: _timerSeconds == 0 ? Colors.white70 : AppColors.gold,
                          ),
                          onPressed: _cycleTimer,
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
                        child: _countdown > 0
                            // While counting down the user is stepping back into
                            // frame, so the number has to read from a distance.
                            ? Text(
                                '$_countdown',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 96,
                                  fontWeight: FontWeight.bold,
                                  shadows: [Shadow(color: Colors.black54, blurRadius: 12)],
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(12)),
                                child: Text(context.tr('scan_hint'), style: const TextStyle(color: Colors.white)),
                              ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 40),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _RoundAction(
                                icon: Icons.photo_library_outlined,
                                label: _step == 0 ? context.tr('scan_pick_two') : context.tr('scan_from_gallery'),
                                onTap: _pickFromGallery,
                              ),
                              const SizedBox(width: 28),
                              GestureDetector(
                                onTap: _onShutter,
                                child: Container(
                                  width: 74,
                                  height: 74,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 4),
                                  ),
                                  child: _capturing
                                      ? const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : _countdown > 0
                                          ? const Icon(Icons.close, color: Colors.white, size: 32)
                                          : Container(
                                              margin: const EdgeInsets.all(6),
                                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                            ),
                                ),
                              ),
                              // Balances the gallery button so the shutter stays centred.
                              const SizedBox(width: 80),
                            ],
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

/// Secondary control next to the shutter, sized to leave the shutter dominant.
class _RoundAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _RoundAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 24),
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
