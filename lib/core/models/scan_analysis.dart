import 'dart:convert';
import 'dart:typed_data';

import 'user.dart';

/// The full `POST /scan` response: the measurements plus, when the request
/// asked for them, the annotated debug frames the pipeline drew (MediaPipe
/// skeleton + rembg body contour).
///
/// The frames are held as decoded bytes in memory only — like the source
/// photos, they are never written to disk (privacy rule F4), and they are not
/// part of [Measurements] precisely because that object *is* persisted.
class ScanAnalysis {
  final Measurements measurements;
  final Uint8List? annotatedFront;
  final Uint8List? annotatedSide;

  const ScanAnalysis({required this.measurements, this.annotatedFront, this.annotatedSide});

  bool get hasAnnotations => annotatedFront != null || annotatedSide != null;

  factory ScanAnalysis.fromApi(Map<String, dynamic> body) {
    final images = body['annotated_images'];
    final map = images is Map ? images : const {};
    return ScanAnalysis(
      measurements: Measurements.fromApi(body),
      annotatedFront: decodeAnnotatedImage(map['front']),
      annotatedSide: decodeAnnotatedImage(map['side']),
    );
  }

  ScanAnalysis copyWith({Measurements? measurements}) => ScanAnalysis(
        measurements: measurements ?? this.measurements,
        annotatedFront: annotatedFront,
        annotatedSide: annotatedSide,
      );
}

final _dataUriPrefix = RegExp(r'^data:image/[a-zA-Z+]+;base64,');

/// Decodes one annotated frame, which the API sends as a data URI
/// (`data:image/jpeg;base64,…`) rather than bare base64.
///
/// Returns null on anything unexpected: these images are a diagnostic extra,
/// so a malformed one must never take down a scan that measured fine.
Uint8List? decodeAnnotatedImage(Object? value) {
  if (value is! String || value.isEmpty) return null;
  try {
    return base64Decode(value.replaceFirst(_dataUriPrefix, '').trim());
  } catch (_) {
    return null;
  }
}
