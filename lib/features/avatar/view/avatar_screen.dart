import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../../core/di/injector.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/user.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/model_storage.dart';

/// Matches the try-on scene so the mesh does not appear to change environment
/// when the user moves from their bare avatar to a garment draped on it.
const _sceneBackground = Color(0xFF0E1526);

/// The scanned body mesh, full screen.
///
/// Sits between the scan result and the catalog: the `.glb` from `POST
/// /scan-3d` is the payoff for the scan, and the CTA hands the user straight to
/// a garment to drape on it (guide §5.3 → §5.6). Reachable again later from the
/// profile.
class AvatarScreen extends StatelessWidget {
  /// Where "continue" goes once the user is done with the avatar — the step the
  /// scan flow would otherwise have gone to. Null when the screen is opened
  /// from the profile, where the back button is the way out.
  final String? nextRoute;

  const AvatarScreen({super.key, this.nextRoute});

  @override
  Widget build(BuildContext context) {
    // Read on every build — it is an in-memory lookup — but key the body on the
    // mesh path. As a bottom-nav tab this widget is kept alive across tab
    // switches, so resolving once and never again would leave a stale avatar on
    // screen after a re-scan. A changed path swaps the state (and the webview);
    // an unchanged one leaves both completely untouched.
    final measurements = sl<AuthRepository>().currentUser?.measurements;
    return _AvatarBody(
      key: ValueKey(measurements?.modelPath),
      measurements: measurements,
      nextRoute: nextRoute,
    );
  }
}

class _AvatarBody extends StatefulWidget {
  final Measurements? measurements;
  final String? nextRoute;

  const _AvatarBody({super.key, required this.measurements, required this.nextRoute});

  @override
  State<_AvatarBody> createState() => _AvatarBodyState();
}

class _AvatarBodyState extends State<_AvatarBody> {
  /// Resolved once per mesh, not in `build`: rebuilding the future would tear
  /// the webview down and re-load a multi-megabyte mesh on every repaint.
  late final Future<String?> _meshPath;
  Measurements? get _measurements => widget.measurements;

  @override
  void initState() {
    super.initState();
    _meshPath = ModelStorage.resolve(_measurements?.modelPath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _sceneBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        // Post-scan there is nothing meaningful behind this screen — the camera
        // and result steps replaced each other.
        automaticallyImplyLeading: widget.nextRoute == null,
        title: Text(context.tr('body_model_3d'), style: const TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              Expanded(
                child: FutureBuilder<String?>(
                  future: _meshPath,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    }
                    final path = snapshot.data;
                    if (path == null) return const _MissingMesh();
                    return _AvatarViewer(path: path);
                  },
                ),
              ),
              // The panel is intrinsically sized, so on a short screen at a
              // large text scale it grows past the column and overflows. Cap it
              // and let it scroll instead — the mesh keeps the rest.
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.6),
                child: SingleChildScrollView(
                  child: _AvatarPanel(
                    measurements: _measurements,
                    nextRoute: widget.nextRoute,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keyed on the path so a replaced mesh tears the old webview down rather than
/// re-using it — the viewer holds the whole mesh in memory (guide §11).
class _AvatarViewer extends StatelessWidget {
  final String path;
  const _AvatarViewer({required this.path});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ModelViewer(
            key: ValueKey(path),
            src: 'file://$path',
            alt: context.tr('body_model_3d'),
            cameraControls: true, // drag = rotate, pinch = zoom
            autoRotate: false,
            disableZoom: false,
            backgroundColor: _sceneBackground,
          ),
        ),
        Positioned(
          bottom: 8,
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
    );
  }
}

/// The mesh failed to build or was evicted. Not an error state — the
/// measurements are the product, and the try-on CTA still works.
class _MissingMesh extends StatelessWidget {
  const _MissingMesh();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.view_in_ar_outlined, color: Colors.white38, size: 72),
            const SizedBox(height: 16),
            Text(
              context.tr('avatar_missing'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarPanel extends StatelessWidget {
  final Measurements? measurements;
  final String? nextRoute;
  const _AvatarPanel({required this.measurements, required this.nextRoute});

  @override
  Widget build(BuildContext context) {
    final m = measurements;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 20, 20, 16 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr('avatar_ready'),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('avatar_sub'),
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
          if (m != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                _Stat(label: context.tr('chest'), value: '${m.chest}'),
                _Stat(label: context.tr('waist'), value: '${m.waist}'),
                _Stat(label: context.tr('hips'), value: '${m.hips}'),
                _Stat(label: context.tr('your_size'), value: m.recommendedSize, highlight: true),
              ],
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              // Straight into the catalog: the user picks a garment, and the
              // product page's own Try On button opens the 3D try-on for it.
              onPressed: () => context.go(Routes.explore),
              icon: const Icon(Icons.checkroom_outlined),
              label: Text(context.tr('try_on_cta')),
            ),
          ),
          if (nextRoute != null)
            Center(
              child: TextButton(
                onPressed: () => context.go(nextRoute!),
                child: Text(
                  context.tr('avatar_continue'),
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _Stat({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: highlight ? AppColors.gold : Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
