import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sensors_plus/sensors_plus.dart';

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

  /// A tilted phone foreshortens the body and skews every circumference the
  /// backend derives, so the shutter stays locked past this much lean in
  /// either axis (guide §10 asks for 0°; a few degrees is the practical floor
  /// for a handheld device).
  static const double _maxTiltDegrees = 8;

  CameraController? _controller;
  int _step = 0; // 0 = front, 1 = side
  File? _front;
  bool _initializing = true;
  bool _capturing = false;
  String? _error;
  int _timerSeconds = 0;
  int _countdown = 0;
  Timer? _countdownTimer;

  /// Worst-axis lean in whole degrees, or null when the device reports no
  /// accelerometer — the gate then stays open rather than trapping the user.
  final ValueNotifier<int?> _tilt = ValueNotifier(null);
  StreamSubscription<AccelerometerEvent>? _tiltSub;
  double _smoothedTilt = 0;

  bool get _isLevel => _tilt.value == null || _tilt.value! <= _maxTiltDegrees;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _watchTilt();
  }

  /// Gravity tells us how the phone is held: with it upright in portrait the
  /// vector sits almost entirely on Y, so any weight on X (side roll) or Z
  /// (leaning toward/away from the user) is the tilt we care about.
  void _watchTilt() {
    _tiltSub = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen(
      (event) {
        const rad2deg = 180 / math.pi;
        final roll = math.atan2(event.x, event.y) * rad2deg;
        final pitch =
            math.atan2(event.z, math.sqrt(event.x * event.x + event.y * event.y)) * rad2deg;
        final worst = math.max(roll.abs(), pitch.abs());
        // Low-pass: raw accelerometer readings jitter by several degrees while
        // the phone is simply being held.
        _smoothedTilt = _smoothedTilt * 0.8 + worst * 0.2;
        final rounded = _smoothedTilt.round();
        // Only whole-degree changes repaint the indicator.
        if (_tilt.value != rounded) _tilt.value = rounded;
      },
      // No sensor (web, desktop, some emulators): leave the gate open.
      onError: (_) => _tilt.value = null,
      cancelOnError: true,
    );
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
      // 1080p is the minimum the scan engine is specified against (guide §10);
      // `veryHigh` is the first preset that clears it.
      final controller = CameraController(camera, ResolutionPreset.veryHigh, enableAudio: false);
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
    if (!_isLevel) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('scan_hold_straight'))));
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
      // as the 1080p live capture.
      final picked = _step == 0
          ? await picker.pickMultiImage(limit: 2, maxWidth: 1080, maxHeight: 1920)
          : [?await picker.pickImage(source: ImageSource.gallery, maxWidth: 1080, maxHeight: 1920)];
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
    _tiltSub?.cancel();
    _tilt.dispose();
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
                      // Centred, not Positioned.fill: filling forces tight
                      // constraints that defeat CameraPreview's own AspectRatio
                      // and stretch the image. Letterboxing against the black
                      // background also keeps the preview honest — what the
                      // user frames is exactly what gets captured, which the
                      // guide overlay depends on, so it rides inside the same
                      // rect as the preview.
                      Center(
                        child: CameraPreview(
                          _controller!,
                          child: const IgnorePointer(child: CustomPaint(painter: _BodyGuidePainter())),
                        ),
                      ),
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
                      Positioned(
                        bottom: 160,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: ValueListenableBuilder<int?>(
                            valueListenable: _tilt,
                            builder: (context, tilt, __) =>
                                _LevelIndicator(tilt: tilt, maxTilt: _maxTiltDegrees),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

/// Live pitch/roll readout. Green once the phone is upright enough to shoot,
/// amber while it is off — the shutter refuses to fire in the amber state.
class _LevelIndicator extends StatelessWidget {
  final int? tilt;
  final double maxTilt;
  const _LevelIndicator({required this.tilt, required this.maxTilt});

  @override
  Widget build(BuildContext context) {
    // No sensor: no claim about levelness, so show nothing at all.
    if (tilt == null) return const SizedBox.shrink();
    final level = tilt! <= maxTilt;
    final color = level ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(level ? Icons.check_circle : Icons.screen_rotation_alt, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            level ? context.tr('scan_level_ok') : '${context.tr('scan_hold_straight')} · $tilt°',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
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
