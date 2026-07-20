import '../models/user.dart';
import '../utils/result.dart';

abstract class BodyScanRepository {
  /// Mock AI analysis. Photos are never persisted — only the numeric
  /// measurements returned here are stored downstream.
  Future<Result<Measurements>> analyze();
}

class MockBodyScanRepository implements BodyScanRepository {
  @override
  Future<Result<Measurements>> analyze() async {
    // Simulates 2–3s AI processing.
    await Future.delayed(const Duration(milliseconds: 2500));
    return const Success(Measurements(chest: 92, waist: 78, hips: 100, height: 172, weight: 74));
  }
}
