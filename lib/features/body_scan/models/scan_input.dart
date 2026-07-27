import 'dart:io';

/// Carries the scan inputs across the intro → camera → result screens via
/// go_router's `extra`, so no global state is needed.
class ScanInput {
  final double heightCm;
  final File? front;
  final File? side;

  /// True when the camera screen was opened from the manual-entry flow: on
  /// completion it should hand the two files back to the caller instead of
  /// pushing straight into the analyze pipeline.
  final bool manualPhotoCapture;

  const ScanInput({required this.heightCm, this.front, this.side, this.manualPhotoCapture = false});

  bool get isComplete => front != null && side != null;

  ScanInput copyWith({File? front, File? side}) => ScanInput(
        heightCm: heightCm,
        front: front ?? this.front,
        side: side ?? this.side,
        manualPhotoCapture: manualPhotoCapture,
      );
}
