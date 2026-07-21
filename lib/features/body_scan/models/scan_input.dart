import 'dart:io';

/// Carries the scan inputs across the intro → camera → result screens via
/// go_router's `extra`, so no global state is needed.
class ScanInput {
  final double heightCm;
  final File? front;
  final File? side;

  const ScanInput({required this.heightCm, this.front, this.side});

  bool get isComplete => front != null && side != null;

  ScanInput copyWith({File? front, File? side}) =>
      ScanInput(heightCm: heightCm, front: front ?? this.front, side: side ?? this.side);
}
