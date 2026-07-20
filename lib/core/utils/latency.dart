import 'dart:math';

import '../config/app_config.dart';

/// Simulates realistic network latency for mock data sources so that
/// loading / error states are genuinely exercised.
Future<void> mockLatency() {
  final min = AppConfig.mockMinLatency.inMilliseconds;
  final max = AppConfig.mockMaxLatency.inMilliseconds;
  final ms = min + Random().nextInt(max - min + 1);
  return Future.delayed(Duration(milliseconds: ms));
}
