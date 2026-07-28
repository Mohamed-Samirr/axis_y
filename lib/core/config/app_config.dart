import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Global app configuration.
///
/// [useMockData] is the single switch between the local mock data layer and
/// the (future) real API. Everything reads repositories through DI, so flipping
/// this flag swaps implementations without touching a single Cubit or View.
abstract class AppConfig {
  static const bool useMockData = true;

  /// Body scan is the first feature with a real backend. It opts out of
  /// [useMockData] on its own so the rest of the app keeps running on mocks.
  /// Setting this to `false` restores the fully offline mock scan.
  static const bool useRealBodyScan = true;

  /// Fit check + virtual try-on against the main API (`/api/v1`). Off until the
  /// gateway is reachable — the mock repository serves the exact same
  /// [FitResult] / [TryOnResult] shapes, so the UI is identical either way.
  static const bool useRealTryOn = bool.fromEnvironment('AXIS_REAL_TRYON');

  /// Override at build time:
  ///   flutter run --dart-define=AXIS_API_BASE=http://192.168.1.7:8000
  static const String _apiBaseOverride = String.fromEnvironment('AXIS_API_BASE');

  static String get apiBaseUrl {
    if (_apiBaseOverride.isNotEmpty) return _apiBaseOverride;
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000'; // emulator loopback
    return 'http://localhost:8000';
  }

  /// The body scan engine (`/scan`, `/scan-3d`) is mounted at the root, the
  /// gateway (products, fit-check, try-on) under this prefix.
  static const String mainApiPrefix = '/api/v1';

  /// The scan pipeline runs MediaPipe + rembg on CPU. 5–30s is normal.
  static const Duration scanTimeout = Duration(seconds: 120);
  static const Duration connectTimeout = Duration(seconds: 15);

  /// Products, fit-check, scan registration — plain JSON round trips.
  static const Duration standardTimeout = Duration(seconds: 10);

  /// Morphing is ~300–600ms but the response carries GLB URLs the client then
  /// downloads, and the gateway may still be cold.
  static const Duration tryOnTimeout = Duration(seconds: 30);

  /// Exponential backoff for 5xx only — never for 422 (guide §9).
  static const int maxRetries = 2;
  static const Duration retryBaseDelay = Duration(milliseconds: 400);

  /// Below this, the scan result warns the user that the photos were unclear.
  static const double lowConfidenceThreshold = 0.85;

  /// Simulated network latency range for mock data sources.
  static const Duration mockMinLatency = Duration(milliseconds: 300);
  static const Duration mockMaxLatency = Duration(milliseconds: 800);

  static const String appName = 'AXIS Y';

  /// OTP that the mock auth/reset flows accept.
  static const String mockOtp = '123456';
}
