import '../config/app_config.dart';
import '../models/catalog.dart';
import '../models/fit.dart';
import '../models/user.dart';
import '../network/api_client.dart';
import '../utils/latency.dart';
import '../utils/result.dart';
import 'auth_repository.dart';

abstract class TryOnRepository {
  /// Fast size verdict with no 3D work — used on the product page (guide §5.5).
  Future<Result<FitResult>> fitCheck({
    required String scanId,
    required Product product,
    required String sizeLabel,
  });

  /// Full try-on: morphs the garment onto the user's mesh and returns the GLB
  /// URLs plus the fit verdict. Called again on every size toggle (guide §5.6).
  Future<Result<TryOnResult>> tryOn({
    required String scanId,
    required Product product,
    required String sizeLabel,
    bool autoSelectSize = false,
  });
}

class ApiTryOnRepository implements TryOnRepository {
  final ApiClient _api;
  ApiTryOnRepository(this._api);

  @override
  Future<Result<FitResult>> fitCheck({
    required String scanId,
    required Product product,
    required String sizeLabel,
  }) async {
    try {
      final res = await _api.dio.post<Map<String, dynamic>>(
        '${AppConfig.mainApiPrefix}/fit-check',
        data: <String, dynamic>{
          'scan_id': scanId,
          'product_id': product.id,
          'size_label': sizeLabel,
        },
        options: standardOptions(),
      );
      final body = res.data ?? const <String, dynamic>{};
      // The endpoint may return the verdict bare or wrapped in `fit_result`.
      // `FitCheckResponse` also carries `alternative_sizes` as a *sibling* of
      // `fit_result` (unlike `/try-on`, which nests it), so fold the sibling in
      // when the nested list is absent or empty — otherwise the size
      // suggestions silently never reach the UI.
      final nested = body['fit_result'] as Map<String, dynamic>?;
      final siblingAlternatives = body['alternative_sizes'] as List?;
      final fit = nested == null
          ? body
          : {
              ...nested,
              if ((nested['alternative_sizes'] as List?)?.isNotEmpty != true &&
                  siblingAlternatives != null)
                'alternative_sizes': siblingAlternatives,
            };
      return Success(FitResult.fromApi(fit).withSize(sizeLabel));
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }

  @override
  Future<Result<TryOnResult>> tryOn({
    required String scanId,
    required Product product,
    required String sizeLabel,
    bool autoSelectSize = false,
  }) async {
    try {
      final res = await _api.dio.post<Map<String, dynamic>>(
        '${AppConfig.mainApiPrefix}/try-on',
        data: <String, dynamic>{
          'scan_id': scanId,
          // The catalog does not expose per-size variant ids yet, so the
          // product + size pair identifies the variant. Swap in
          // `product_variant_id` once `GET /products` returns real ones.
          'product_id': product.id,
          'size_label': sizeLabel,
          'auto_select_size': autoSelectSize,
        },
        options: tryOnOptions(),
      );
      final result = TryOnResult.fromApi(res.data ?? const {});
      return Success(TryOnResult(
        tryonId: result.tryonId,
        bodyGlbUrl: result.bodyGlbUrl,
        garmentGlbUrl: result.garmentGlbUrl,
        // Keep the size the verdict belongs to, so auto-selection is visible.
        fitResult: result.fitResult.withSize(result.fitResult.sizeLabel ?? sizeLabel),
      ));
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }
}

/// Offline stand-in for the `FitEngine`.
///
/// This is the **only** place in the app allowed to derive a verdict from
/// measurements (guide §4) — it exists so the try-on screen is demoable with no
/// gateway, and it never runs when [AppConfig.useRealTryOn] is on. It returns
/// no GLB URLs, so the viewer falls back to the painted mannequin.
class MockTryOnRepository implements TryOnRepository {
  final AuthRepository _auth;
  MockTryOnRepository(this._auth);

  static const _fallback = Measurements(chest: 92, waist: 78, hips: 100, height: 172, weight: 74);

  @override
  Future<Result<FitResult>> fitCheck({
    required String scanId,
    required Product product,
    required String sizeLabel,
  }) async {
    await mockLatency();
    return Success(_synthesize(product, sizeLabel));
  }

  @override
  Future<Result<TryOnResult>> tryOn({
    required String scanId,
    required Product product,
    required String sizeLabel,
    bool autoSelectSize = false,
  }) async {
    await mockLatency();
    final measurements = _auth.currentUser?.measurements ?? _fallback;
    final label = autoSelectSize
        ? (product.sizes.any((s) => s.label == measurements.recommendedSize)
            ? measurements.recommendedSize
            : sizeLabel)
        : sizeLabel;
    return Success(TryOnResult(
      tryonId: 'mock-${product.id}-$label',
      fitResult: _synthesize(product, label),
    ));
  }

  FitResult _synthesize(Product product, String sizeLabel) {
    final m = _auth.currentUser?.measurements ?? _fallback;
    final size = product.sizes.firstWhere(
      (s) => s.label == sizeLabel,
      orElse: () => product.sizes.first,
    );

    final regions = [
      _region('chest_cm', m.chest.toDouble(), size.chest.toDouble()),
      _region('waist_cm', m.waist.toDouble(), size.waist.toDouble()),
      _region('hips_cm', m.hips.toDouble(), (size.waist + 8).toDouble()),
    ];

    // Overall = the worst region, which is how ease-based sizing behaves.
    final overall = regions
        .map((r) => r.verdict)
        .reduce((a, b) => _severity(a) >= _severity(b) ? a : b);

    final alternatives = product.sizes
        .where((s) => s.label != sizeLabel && s.available)
        .map((s) => AlternativeSize(
              sizeLabel: s.label,
              predictedVerdict: _verdictFor(s.chest.toDouble() - m.chest),
            ))
        .toList();

    return FitResult(
      overallVerdict: overall,
      overallConfidence: m.confidence ?? 0.9,
      regions: regions,
      alternativeSizes: alternatives,
      sizeLabel: sizeLabel,
    );
  }

  FitRegion _region(String name, double body, double garment) {
    final ease = garment - body;
    return FitRegion(
      name: name,
      bodyCm: body,
      garmentCm: garment,
      easeCm: ease,
      verdict: _verdictFor(ease),
    );
  }

  static FitVerdict _verdictFor(double ease) {
    if (ease < -2) return FitVerdict.notRecommended;
    if (ease < 1) return FitVerdict.tooTight;
    if (ease < 3) return FitVerdict.slimFit;
    if (ease <= 8) return FitVerdict.perfectFit;
    if (ease <= 14) return FitVerdict.looseFit;
    return FitVerdict.tooLoose;
  }

  static int _severity(FitVerdict v) => switch (v) {
        FitVerdict.perfectFit => 0,
        FitVerdict.slimFit => 1,
        FitVerdict.looseFit => 2,
        FitVerdict.tooLoose => 3,
        FitVerdict.tooTight => 4,
        FitVerdict.notRecommended => 5,
        FitVerdict.unknown => 1,
      };
}
