import 'package:axis_y/core/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Measurements.fromApi', () {
    test('parses the /scan response and rounds doubles to ints', () {
      final body = {
        'success': true,
        'measurements': {
          'height_cm': 175.0,
          'shoulder_cm': 44.2,
          'chest_cm': 98.7,
          'waist_cm': 84.1,
          'hips_cm': 99.3,
          'inseam_cm': 79.5,
          'weight_kg_estimate': 74.6,
        },
        'confidence': 0.9713,
      };

      final m = Measurements.fromApi(body);

      expect(m.height, 175);
      expect(m.chest, 99); // 98.7 rounds up
      expect(m.waist, 84);
      expect(m.hips, 99);
      expect(m.weight, 75); // 74.6 rounds up
      expect(m.shoulderCm, 44.2);
      expect(m.inseamCm, 79.5);
      // confidence sits at the top level, not inside `measurements`.
      expect(m.confidence, 0.9713);
    });

    test('tolerates a missing top-level confidence', () {
      final m = Measurements.fromApi({
        'measurements': {
          'height_cm': 170,
          'shoulder_cm': 42,
          'chest_cm': 92,
          'waist_cm': 78,
          'hips_cm': 100,
          'inseam_cm': 76,
          'weight_kg_estimate': 70,
        },
      });
      expect(m.confidence, isNull);
      expect(m.chest, 92);
    });

    test('derives the recommended size from the scanned chest', () {
      final m = Measurements.fromApi({
        'measurements': {
          'height_cm': 175.0,
          'shoulder_cm': 44.2,
          'chest_cm': 98.7,
          'waist_cm': 84.1,
          'hips_cm': 99.3,
          'inseam_cm': 79.5,
          'weight_kg_estimate': 74.6,
        },
        'confidence': 0.97,
      });
      // chest rounds to 99 -> just past the M threshold of 98.
      expect(m.recommendedSize, 'L');
    });
  });

  group('Measurements.fromJson', () {
    test('loads a legacy profile saved before the scan API existed', () {
      // No shoulderCm / inseamCm / confidence / modelPath keys at all.
      final m = Measurements.fromJson({
        'chest': 92,
        'waist': 78,
        'hips': 100,
        'height': 172,
        'weight': 74,
      });

      expect(m.chest, 92);
      expect(m.shoulderCm, isNull);
      expect(m.inseamCm, isNull);
      expect(m.confidence, isNull);
      expect(m.modelPath, isNull);
    });

    test('accepts ints that round-tripped through JSON as doubles', () {
      // `as int` would throw here; `as num` then .toInt() must not.
      final m = Measurements.fromJson({
        'chest': 92.0,
        'waist': 78.0,
        'hips': 100.0,
        'height': 172.0,
        'weight': 74.0,
      });
      expect(m.chest, 92);
      expect(m.height, 172);
    });

    test('survives a full toJson/fromJson round trip with the new fields', () {
      const original = Measurements(
        chest: 99,
        waist: 84,
        hips: 99,
        height: 175,
        weight: 75,
        shoulderCm: 44.2,
        inseamCm: 79.5,
        confidence: 0.9713,
        modelPath: 'body_model.glb',
      );

      final restored = Measurements.fromJson(original.toJson());

      expect(restored, original);
      expect(restored.modelPath, 'body_model.glb');
    });
  });

  group('copyWith', () {
    test('attaches a model path without disturbing the measurements', () {
      const m = Measurements(
        chest: 99,
        waist: 84,
        hips: 99,
        height: 175,
        weight: 75,
        shoulderCm: 44.2,
        confidence: 0.97,
      );

      final withModel = m.copyWith(modelPath: 'body_model.glb');

      expect(withModel.modelPath, 'body_model.glb');
      expect(withModel.chest, 99);
      expect(withModel.shoulderCm, 44.2);
      expect(withModel.confidence, 0.97);
    });

    test('a null model path leaves an existing one intact', () {
      const m = Measurements(
        chest: 99, waist: 84, hips: 99, height: 175, weight: 75,
        modelPath: 'body_model.glb',
      );
      expect(m.copyWith(modelPath: null).modelPath, 'body_model.glb');
    });
  });

  group('Measurements.toApiMeasurements', () {
    // `BodyMeasurementsSchema` marks all six of these required — a missing
    // shoulder_cm/inseam_cm is a 422 from the live API, which locks the user
    // out of fit-check and try-on entirely.
    const requiredByApi = [
      'height_cm', 'shoulder_cm', 'chest_cm', 'waist_cm', 'hips_cm', 'inseam_cm',
    ];

    test('sends every field the API requires when the scan supplied them', () {
      const m = Measurements(
        chest: 99, waist: 84, hips: 99, height: 175, weight: 75,
        shoulderCm: 44.2, inseamCm: 79.5,
      );

      final payload = m.toApiMeasurements();

      expect(payload.keys, containsAll(requiredByApi));
      expect(payload['shoulder_cm'], 44.2);
      expect(payload['inseam_cm'], 79.5);
      expect(payload['weight_kg_estimate'], 75.0);
    });

    test('substitutes height-derived estimates on the manual entry path', () {
      // Both left blank in the manual form — the API still demands them.
      const m = Measurements(chest: 92, waist: 78, hips: 100, height: 172, weight: 74);

      final payload = m.toApiMeasurements();

      expect(payload.keys, containsAll(requiredByApi));
      expect(payload['shoulder_cm'], closeTo(44.2, 0.5));
      expect(payload['inseam_cm'], closeTo(79.5, 0.5));
      // The stored values stay null so the result screen keeps hiding rows the
      // user never actually provided.
      expect(m.shoulderCm, isNull);
      expect(m.inseamCm, isNull);
    });

    test('never emits a zero for an unknown measurement', () {
      const m = Measurements(chest: 92, waist: 78, hips: 100, height: 172, weight: 74);
      for (final key in requiredByApi) {
        expect(m.toApiMeasurements()[key], isNot(0), reason: '$key must be a real value');
      }
    });
  });
}
