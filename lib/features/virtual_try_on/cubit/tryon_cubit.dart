import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/catalog.dart';
import '../../../core/models/fit.dart';
import '../../../core/models/user.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/repositories/catalog_repository.dart';
import '../../../core/repositories/tryon_repository.dart';
import '../../../core/services/glb_cache.dart';
import '../../../core/services/session_service.dart';

sealed class TryOnState extends Equatable {
  const TryOnState();
  @override
  List<Object?> get props => [];
}

class TryOnLoading extends TryOnState {
  const TryOnLoading();
}

class TryOnError extends TryOnState {
  final String message;
  const TryOnError(this.message);
  @override
  List<Object?> get props => [message];
}

class TryOnReady extends TryOnState {
  final Product product;
  final int colorIndex;
  final String size;
  final Measurements measurements;

  /// Backend verdict for [size]. Null while the first call is in flight, or
  /// when the user has no registered scan.
  final FitResult? fit;

  /// Local path of the cached `.glb`. Null keeps the painted mannequin on
  /// screen — a missing mesh is never a failure state.
  final String? meshPath;

  /// True while a size toggle is being morphed server-side. The previous mesh
  /// stays visible underneath so the screen never flashes empty.
  final bool morphing;

  /// Non-fatal error key from the last try-on call.
  final String? fitError;

  /// No `scan_id` yet — the user has measurements but nothing registered, so
  /// the screen invites them to scan instead of showing a verdict.
  final bool needsScan;

  const TryOnReady({
    required this.product,
    required this.colorIndex,
    required this.size,
    required this.measurements,
    this.fit,
    this.meshPath,
    this.morphing = false,
    this.fitError,
    this.needsScan = false,
  });

  ProductColor get color => product.colors[colorIndex];

  /// Sizes the user can toggle between (guide §5.6).
  List<ProductSize> get sizes => product.sizes;

  TryOnReady copyWith({
    int? colorIndex,
    String? size,
    FitResult? fit,
    String? meshPath,
    bool? morphing,
    String? fitError,
    bool? needsScan,
    bool clearFit = false,
    bool clearError = false,
    bool clearMesh = false,
  }) =>
      TryOnReady(
        product: product,
        colorIndex: colorIndex ?? this.colorIndex,
        size: size ?? this.size,
        measurements: measurements,
        fit: clearFit ? null : (fit ?? this.fit),
        meshPath: clearMesh ? null : (meshPath ?? this.meshPath),
        morphing: morphing ?? this.morphing,
        fitError: clearError ? null : (fitError ?? this.fitError),
        needsScan: needsScan ?? this.needsScan,
      );

  @override
  List<Object?> get props =>
      [product.id, colorIndex, size, fit, meshPath, morphing, fitError, needsScan];
}

/// ViewModel for the 3D try-on. Every verdict and every vertex comes from the
/// backend (guide §4) — this class only sequences the calls and caches results.
class TryOnCubit extends Cubit<TryOnState> {
  final CatalogRepository _catalog;
  final TryOnRepository _tryOn;
  final AuthRepository _auth;
  final SessionService _session;
  final GlbCache _glb;

  /// Per-size results, so toggling back to a size already viewed is instant and
  /// costs no network (guide §8).
  final Map<String, TryOnResult> _bySize = {};
  final Map<String, String?> _meshBySize = {};

  TryOnCubit(this._catalog, this._tryOn, this._auth, this._session, this._glb)
      : super(const TryOnLoading());

  void _safeEmit(TryOnState state) {
    if (!isClosed) emit(state);
  }

  Future<void> load(String productId) async {
    emit(const TryOnLoading());
    final result = await _catalog.getProduct(productId);
    await result.when(
      success: (product) async {
        final measurements = _auth.currentUser?.measurements ??
            const Measurements(chest: 92, waist: 78, hips: 100, height: 172, weight: 74);
        final recommended = measurements.recommendedSize;
        final size = product.sizes.any((s) => s.label == recommended)
            ? recommended
            : product.sizes.first.label;
        _safeEmit(TryOnReady(
          product: product,
          colorIndex: 0,
          size: size,
          measurements: measurements,
          morphing: _session.hasScan,
          needsScan: !_session.hasScan,
        ));
        // First view asks the backend to pick the size it recommends; later
        // toggles are explicit user choices.
        if (_session.hasScan) await _morph(size, autoSelectSize: true);
      },
      failure: (m) async => _safeEmit(TryOnError(m)),
    );
  }

  void selectColor(int index) {
    final s = state;
    if (s is TryOnReady) emit(s.copyWith(colorIndex: index));
  }

  /// Size toggle: re-runs the try-on for [label] and swaps the mesh in.
  Future<void> selectSize(String label) async {
    final s = state;
    if (s is! TryOnReady || s.size == label) return;

    final cached = _bySize[label];
    if (cached != null) {
      _safeEmit(s.copyWith(
        size: label,
        fit: cached.fitResult,
        meshPath: _meshBySize[label],
        // Never leave the previous size's mesh on screen under a new label.
        clearMesh: _meshBySize[label] == null,
        morphing: false,
        clearError: true,
      ));
      return;
    }

    _safeEmit(s.copyWith(size: label, morphing: true, clearFit: true, clearError: true));
    if (!_session.hasScan) {
      _safeEmit((state as TryOnReady).copyWith(morphing: false, needsScan: true));
      return;
    }
    await _morph(label);
  }

  Future<void> retry() async {
    final s = state;
    if (s is TryOnReady) {
      _safeEmit(s.copyWith(morphing: true, clearError: true));
      await _morph(s.size);
    }
  }

  Future<void> _morph(String size, {bool autoSelectSize = false}) async {
    final s = state;
    if (s is! TryOnReady) return;

    // The scan can be dropped mid-session — by a 404 here or on the product
    // page — so re-read it rather than trusting the caller's check.
    final scanId = _session.scanId;
    if (scanId == null) {
      _safeEmit(s.copyWith(morphing: false, needsScan: true, clearError: true));
      return;
    }

    final result = await _tryOn.tryOn(
      scanId: scanId,
      product: s.product,
      sizeLabel: size,
      autoSelectSize: autoSelectSize,
    );

    await result.when(
      success: (data) async {
        // The backend may hand back a different size than requested when
        // auto-selection is on; the UI follows whatever it decided.
        final label = data.fitResult.sizeLabel ?? size;
        _bySize[label] = data;

        final afterFit = state;
        if (afterFit is! TryOnReady) return;
        // A newer toggle may have landed while this was in flight; only the
        // size still on screen may repaint.
        if (afterFit.size != size && afterFit.size != label) return;

        // Verdict first, mesh second. The verdict is what the user is waiting
        // for and it arrives with the response; the mesh is megabytes behind
        // it. Holding the veil up for the whole download is what made a slow
        // mesh look like the screen had frozen. The painted mannequin covers
        // the gap — a missing mesh is never a failure state.
        _safeEmit(afterFit.copyWith(
          size: label,
          fit: data.fitResult,
          meshPath: _meshBySize[label],
          clearMesh: _meshBySize[label] == null,
          morphing: false,
          clearError: true,
        ));

        final mesh = await _resolveMesh(data);
        _meshBySize[label] = mesh;
        if (mesh == null) return;
        final afterMesh = state;
        // The user may have toggled again during the download; the mesh is
        // cached under its own size either way, so just drop this repaint.
        if (afterMesh is! TryOnReady || afterMesh.size != label) return;
        _safeEmit(afterMesh.copyWith(meshPath: mesh));
      },
      failure: (key) async {
        // 404 = the stored scan no longer exists server-side (guide §12).
        if (key == 'err_scan_missing') await _session.clearScan();
        final current = state;
        if (current is! TryOnReady) return;
        _safeEmit(current.copyWith(
          morphing: false,
          fitError: key,
          needsScan: key == 'err_scan_missing',
        ));
      },
    );
  }

  /// Downloads (or reuses) the mesh for this result.
  ///
  /// `model_viewer_plus` renders a single `src`, so the garment GLB — which the
  /// morph engine bakes onto the body — wins when both are present. If the
  /// backend keeps them as separate meshes we need a merged GLB from them
  /// rather than a second viewer (guide §11, open question).
  Future<String?> _resolveMesh(TryOnResult result) async {
    final url = result.garmentGlbUrl ?? result.bodyGlbUrl;
    if (url == null || url.isEmpty) return null;
    return _glb.resolve(url);
  }
}
