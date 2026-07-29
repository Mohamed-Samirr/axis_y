import 'package:axis_y/core/utils/image_orientation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  group('bakeOrientationBytes', () {
    test('rotates a landscape buffer tagged "rotate 90" into real portrait pixels', () {
      // Exactly what CameraController.takePicture() hands us on Android for a
      // portrait shot: sideways pixels plus an EXIF tag asking for the turn.
      final source = img.Image(width: 80, height: 40);
      source.exif.imageIfd.orientation = 6;

      final baked = bakeOrientationBytes(img.encodeJpg(source))!;
      final result = img.decodeImage(baked)!;

      expect(result.width, 40);
      expect(result.height, 80);
      // The tag must be cleared too, or a reader that *does* honour EXIF would
      // turn the already-turned pixels a second time.
      expect(result.exif.imageIfd.orientation, anyOf(isNull, 1));
    });

    test('leaves an already-upright image the same shape', () {
      final source = img.Image(width: 40, height: 80);

      final result = img.decodeImage(bakeOrientationBytes(img.encodeJpg(source))!)!;

      expect(result.width, 40);
      expect(result.height, 80);
    });

    test('is idempotent — baking twice does not rotate twice', () {
      final source = img.Image(width: 80, height: 40);
      source.exif.imageIfd.orientation = 6;

      final once = bakeOrientationBytes(img.encodeJpg(source))!;
      final twice = bakeOrientationBytes(once)!;
      final result = img.decodeImage(twice)!;

      expect(result.width, 40);
      expect(result.height, 80);
    });

    test('returns null for bytes that are not an image', () {
      expect(bakeOrientationBytes(img.encodeJpg(img.Image(width: 1, height: 1)).sublist(0, 4)), isNull);
    });
  });
}
