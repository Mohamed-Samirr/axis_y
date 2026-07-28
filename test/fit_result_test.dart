import 'package:axis_y/core/localization/app_strings.dart';
import 'package:axis_y/core/models/fit.dart';
import 'package:flutter_test/flutter_test.dart';

/// The exact payload from the integration guide (§7).
const _guideSample = <String, dynamic>{
  'overall_verdict': 'PERFECT_FIT',
  'overall_confidence': 0.93,
  'regions': {
    'chest_cm': {
      'body_cm': 99.5,
      'garment_cm': 104.0,
      'ease_cm': 4.5,
      'verdict': 'PERFECT_FIT',
      'explanation': 'Chest has a comfortable 4.5cm of room.',
      'constrained': false,
    },
  },
  'recommendation': 'Size M is a great fit for your body measurements.',
  'alternative_sizes': [
    {'size_label': 'L', 'predicted_verdict': 'LOOSE_FIT'},
  ],
  'has_constraint_warnings': false,
};

void main() {
  group('FitResult.fromApi', () {
    test('parses the documented fit_result payload', () {
      final fit = FitResult.fromApi(_guideSample);

      expect(fit.overallVerdict, FitVerdict.perfectFit);
      expect(fit.overallConfidence, 0.93);
      expect(fit.recommendation, startsWith('Size M'));
      expect(fit.hasConstraintWarnings, isFalse);

      expect(fit.regions, hasLength(1));
      final chest = fit.regions.single;
      expect(chest.name, 'chest_cm');
      expect(chest.labelKey, 'chest'); // matches the AppStrings key
      expect(chest.bodyCm, 99.5);
      expect(chest.garmentCm, 104.0);
      expect(chest.easeCm, 4.5);
      expect(chest.verdict, FitVerdict.perfectFit);
      expect(chest.constrained, isFalse);

      expect(fit.alternativeSizes.single.sizeLabel, 'L');
      expect(fit.alternativeSizes.single.predictedVerdict, FitVerdict.looseFit);
    });

    test('maps every documented verdict', () {
      const cases = {
        'NOT_RECOMMENDED': FitVerdict.notRecommended,
        'TOO_TIGHT': FitVerdict.tooTight,
        'SLIM_FIT': FitVerdict.slimFit,
        'PERFECT_FIT': FitVerdict.perfectFit,
        'LOOSE_FIT': FitVerdict.looseFit,
        'TOO_LOOSE': FitVerdict.tooLoose,
      };
      cases.forEach((raw, expected) {
        expect(FitVerdictX.fromApi(raw), expected, reason: raw);
      });
    });

    test('falls back to unknown for a verdict the backend adds later', () {
      expect(FitVerdictX.fromApi('SNUG_FIT'), FitVerdict.unknown);
      expect(FitVerdictX.fromApi(null), FitVerdict.unknown);
    });

    test('survives a response with no regions or alternatives', () {
      final fit = FitResult.fromApi({'overall_verdict': 'TOO_TIGHT'});
      expect(fit.overallVerdict, FitVerdict.tooTight);
      expect(fit.overallConfidence, 0);
      expect(fit.regions, isEmpty);
      expect(fit.alternativeSizes, isEmpty);
      expect(fit.recommendation, isNull);
    });

    test('withSize records which size the verdict describes', () {
      expect(FitResult.fromApi(_guideSample).withSize('M').sizeLabel, 'M');
    });
  });

  group('TryOnResult.fromApi', () {
    test('parses the try-on response', () {
      final result = TryOnResult.fromApi({
        'tryon_id': 't-1',
        'body_glb_url': 'https://cdn.axisy.app/body.glb',
        'garment_glb_url': 'https://cdn.axisy.app/garment.glb',
        'fit_result': _guideSample,
      });

      expect(result.tryonId, 't-1');
      expect(result.bodyGlbUrl, endsWith('body.glb'));
      expect(result.garmentGlbUrl, endsWith('garment.glb'));
      expect(result.hasMesh, isTrue);
      expect(result.fitResult.overallVerdict, FitVerdict.perfectFit);
    });

    test('treats a mesh-less response as renderable without a GLB', () {
      final result = TryOnResult.fromApi({'tryon_id': 't-2', 'fit_result': _guideSample});
      expect(result.hasMesh, isFalse);
    });
  });

  test('every verdict has an Arabic and English label', () {
    for (final verdict in FitVerdict.values) {
      expect(AppStrings.values['ar']!.containsKey(verdict.key), isTrue, reason: verdict.key);
      expect(AppStrings.values['en']!.containsKey(verdict.key), isTrue, reason: verdict.key);
    }
  });
}
