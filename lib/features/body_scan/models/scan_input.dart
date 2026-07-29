import 'dart:io';

/// Carries the scan inputs across the intro → camera → result screens via
/// go_router's `extra`, so no global state is needed.
class ScanInput {
  final double heightCm;

  /// Optional: the API only takes height and *estimates* weight from the
  /// photos, so a weight typed here is not uploaded — it simply overrides that
  /// estimate in the result, since the user's own scale beats a guess.
  final double? weightKg;

  final File? front;
  final File? side;

  /// True when the camera screen was opened from the manual-entry flow: on
  /// completion it should hand the two files back to the caller instead of
  /// pushing straight into the analyze pipeline.
  final bool manualPhotoCapture;

  const ScanInput({
    required this.heightCm,
    this.weightKg,
    this.front,
    this.side,
    this.manualPhotoCapture = false,
  });

  bool get isComplete => front != null && side != null;

  ScanInput copyWith({File? front, File? side}) => ScanInput(
        heightCm: heightCm,
        weightKg: weightKg,
        front: front ?? this.front,
        side: side ?? this.side,
        manualPhotoCapture: manualPhotoCapture,
      );
}
