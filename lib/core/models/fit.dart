import 'package:equatable/equatable.dart';

/// Backend fit verdicts (guide §7). The client never *computes* these — it only
/// renders what the `FitEngine` returned.
enum FitVerdict { notRecommended, tooTight, slimFit, perfectFit, looseFit, tooLoose, unknown }

extension FitVerdictX on FitVerdict {
  static FitVerdict fromApi(Object? raw) => switch (raw) {
        'NOT_RECOMMENDED' => FitVerdict.notRecommended,
        'TOO_TIGHT' => FitVerdict.tooTight,
        'SLIM_FIT' => FitVerdict.slimFit,
        'PERFECT_FIT' => FitVerdict.perfectFit,
        'LOOSE_FIT' => FitVerdict.looseFit,
        'TOO_LOOSE' => FitVerdict.tooLoose,
        _ => FitVerdict.unknown,
      };

  /// `AppStrings` key — verdicts are shown in the user's language, not in the
  /// backend's enum text.
  String get key => switch (this) {
        FitVerdict.notRecommended => 'verdict_not_recommended',
        FitVerdict.tooTight => 'verdict_too_tight',
        FitVerdict.slimFit => 'verdict_slim_fit',
        FitVerdict.perfectFit => 'verdict_perfect_fit',
        FitVerdict.looseFit => 'verdict_loose_fit',
        FitVerdict.tooLoose => 'verdict_too_loose',
        FitVerdict.unknown => 'verdict_unknown',
      };

  /// Drives the green/amber/red treatment in the UI.
  FitTone get tone => switch (this) {
        FitVerdict.perfectFit => FitTone.good,
        FitVerdict.slimFit || FitVerdict.looseFit => FitTone.caution,
        FitVerdict.tooTight || FitVerdict.tooLoose || FitVerdict.notRecommended => FitTone.bad,
        FitVerdict.unknown => FitTone.caution,
      };
}

enum FitTone { good, caution, bad }

/// One measured region of the garment against the body.
class FitRegion extends Equatable {
  /// API key, e.g. `chest_cm`.
  final String name;
  final double bodyCm;
  final double garmentCm;
  final double easeCm;
  final FitVerdict verdict;

  /// Server-authored copy ("Chest has a comfortable 4.5cm of room"). Optional
  /// and English-only today, so the UI keeps it secondary to [verdict].
  final String? explanation;
  final bool constrained;

  const FitRegion({
    required this.name,
    required this.bodyCm,
    required this.garmentCm,
    required this.easeCm,
    required this.verdict,
    this.explanation,
    this.constrained = false,
  });

  /// `chest_cm` -> `chest`, which is already an `AppStrings` key.
  String get labelKey => name.endsWith('_cm') ? name.substring(0, name.length - 3) : name;

  factory FitRegion.fromApi(String name, Map<String, dynamic> json) {
    double d(String k) => (json[k] as num?)?.toDouble() ?? 0;
    return FitRegion(
      name: name,
      bodyCm: d('body_cm'),
      garmentCm: d('garment_cm'),
      easeCm: d('ease_cm'),
      verdict: FitVerdictX.fromApi(json['verdict']),
      explanation: json['explanation'] as String?,
      constrained: json['constrained'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [name, bodyCm, garmentCm, easeCm, verdict, constrained];
}

class AlternativeSize extends Equatable {
  final String sizeLabel;
  final FitVerdict predictedVerdict;

  const AlternativeSize({required this.sizeLabel, required this.predictedVerdict});

  factory AlternativeSize.fromApi(Map<String, dynamic> json) => AlternativeSize(
        sizeLabel: json['size_label'] as String? ?? '',
        predictedVerdict: FitVerdictX.fromApi(json['predicted_verdict']),
      );

  @override
  List<Object?> get props => [sizeLabel, predictedVerdict];
}

/// The `fit_result` object returned by `POST /fit-check` and `POST /try-on`.
class FitResult extends Equatable {
  final FitVerdict overallVerdict;
  final double overallConfidence;
  final List<FitRegion> regions;
  final String? recommendation;
  final List<AlternativeSize> alternativeSizes;
  final bool hasConstraintWarnings;

  /// Which size the verdict describes. `/try-on` may auto-select a size that
  /// differs from the one the user tapped, so the UI reads it back from here.
  final String? sizeLabel;

  const FitResult({
    required this.overallVerdict,
    required this.overallConfidence,
    this.regions = const [],
    this.recommendation,
    this.alternativeSizes = const [],
    this.hasConstraintWarnings = false,
    this.sizeLabel,
  });

  factory FitResult.fromApi(Map<String, dynamic> json) {
    final rawRegions = json['regions'];
    return FitResult(
      overallVerdict: FitVerdictX.fromApi(json['overall_verdict']),
      overallConfidence: (json['overall_confidence'] as num?)?.toDouble() ?? 0,
      regions: rawRegions is Map<String, dynamic>
          ? rawRegions.entries
              .where((e) => e.value is Map<String, dynamic>)
              .map((e) => FitRegion.fromApi(e.key, e.value as Map<String, dynamic>))
              .toList()
          : const [],
      recommendation: json['recommendation'] as String?,
      alternativeSizes: ((json['alternative_sizes'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AlternativeSize.fromApi)
          .toList(),
      hasConstraintWarnings: json['has_constraint_warnings'] as bool? ?? false,
      sizeLabel: json['size_label'] as String?,
    );
  }

  FitResult withSize(String? label) => FitResult(
        overallVerdict: overallVerdict,
        overallConfidence: overallConfidence,
        regions: regions,
        recommendation: recommendation,
        alternativeSizes: alternativeSizes,
        hasConstraintWarnings: hasConstraintWarnings,
        sizeLabel: label ?? sizeLabel,
      );

  @override
  List<Object?> get props =>
      [overallVerdict, overallConfidence, regions, recommendation, alternativeSizes, sizeLabel];
}

/// `POST /try-on` response. The GLB URLs are remote; [GlbCache] turns them into
/// local files before they reach the viewer.
class TryOnResult extends Equatable {
  final String tryonId;
  final String? bodyGlbUrl;
  final String? garmentGlbUrl;
  final FitResult fitResult;

  const TryOnResult({
    required this.tryonId,
    required this.fitResult,
    this.bodyGlbUrl,
    this.garmentGlbUrl,
  });

  bool get hasMesh => (garmentGlbUrl ?? bodyGlbUrl) != null;

  factory TryOnResult.fromApi(Map<String, dynamic> json) => TryOnResult(
        tryonId: json['tryon_id'] as String? ?? '',
        bodyGlbUrl: json['body_glb_url'] as String?,
        garmentGlbUrl: json['garment_glb_url'] as String?,
        fitResult: FitResult.fromApi(
          (json['fit_result'] as Map<String, dynamic>?) ?? const {},
        ),
      );

  @override
  List<Object?> get props => [tryonId, bodyGlbUrl, garmentGlbUrl, fitResult];
}
