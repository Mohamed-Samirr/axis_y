import 'dart:convert';

import 'package:axis_y/core/models/scan_analysis.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bytes = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10];
  final b64 = base64Encode(bytes);

  Map<String, dynamic> bodyWith(Object? annotated) => {
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
        'confidence': 0.97,
        if (annotated != null) 'annotated_images': annotated,
      };

  group('ScanAnalysis.fromApi', () {
    test('parses measurements when no annotated images were requested', () {
      final a = ScanAnalysis.fromApi(bodyWith(null));

      expect(a.measurements.chest, 99);
      expect(a.hasAnnotations, isFalse);
      expect(a.annotatedFront, isNull);
      expect(a.annotatedSide, isNull);
    });

    test('strips the data URI prefix and decodes both frames', () {
      final a = ScanAnalysis.fromApi(bodyWith({
        'front': 'data:image/jpeg;base64,$b64',
        'side': 'data:image/png;base64,$b64',
      }));

      expect(a.hasAnnotations, isTrue);
      expect(a.annotatedFront, bytes);
      expect(a.annotatedSide, bytes);
      // The measurements still parse alongside them.
      expect(a.measurements.height, 175);
    });

    test('accepts bare base64 with no data URI prefix', () {
      final a = ScanAnalysis.fromApi(bodyWith({'front': b64}));

      expect(a.annotatedFront, bytes);
      expect(a.annotatedSide, isNull);
    });

    test('survives a malformed or missing frame instead of failing the scan', () {
      final a = ScanAnalysis.fromApi(bodyWith({
        'front': 'data:image/jpeg;base64,not valid base64!!',
        'side': null,
      }));

      expect(a.annotatedFront, isNull);
      expect(a.annotatedSide, isNull);
      expect(a.measurements.waist, 84);
    });

    test('survives annotated_images arriving as the wrong shape', () {
      final a = ScanAnalysis.fromApi(bodyWith('nope'));

      expect(a.hasAnnotations, isFalse);
      expect(a.measurements.hips, 99);
    });
  });
}
