import '../models/catalog.dart';
import '../models/user.dart';
import '../utils/latency.dart';
import '../utils/result.dart';

class FitRow {
  final String labelKey; // chest/waist/hips/height
  final int yourValue;
  final int productValue;
  final bool ok;

  const FitRow({
    required this.labelKey,
    required this.yourValue,
    required this.productValue,
    required this.ok,
  });
}

abstract class TryOnRepository {
  /// Prepares the (placeholder) 3D scene for a product. The real AI engine
  /// plugs in behind this interface later.
  Future<Result<bool>> prepareScene(Product product);

  /// Computes fit verdicts by comparing the chosen size against the user's
  /// measurements.
  List<FitRow> compareFit({
    required ProductSize size,
    required Measurements measurements,
  });
}

class MockTryOnRepository implements TryOnRepository {
  @override
  Future<Result<bool>> prepareScene(Product product) async {
    await mockLatency();
    return const Success(true);
  }

  @override
  List<FitRow> compareFit({required ProductSize size, required Measurements measurements}) {
    bool fits(int garment, int body, {int ease = 2}) => garment + ease >= body;
    return [
      FitRow(labelKey: 'chest', yourValue: measurements.chest, productValue: size.chest, ok: fits(size.chest, measurements.chest)),
      FitRow(labelKey: 'waist', yourValue: measurements.waist, productValue: size.waist, ok: fits(size.waist, measurements.waist)),
      FitRow(labelKey: 'hips', yourValue: measurements.hips, productValue: size.waist + 8, ok: fits(size.waist + 8, measurements.hips)),
      FitRow(labelKey: 'height', yourValue: measurements.height, productValue: 168 + size.length ~/ 2, ok: true),
    ];
  }
}
