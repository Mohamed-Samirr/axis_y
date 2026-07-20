/// Global app configuration.
///
/// [useMockData] is the single switch between the local mock data layer and
/// the (future) real API. Everything reads repositories through DI, so flipping
/// this flag swaps implementations without touching a single Cubit or View.
abstract class AppConfig {
  static const bool useMockData = true;

  /// Simulated network latency range for mock data sources.
  static const Duration mockMinLatency = Duration(milliseconds: 300);
  static const Duration mockMaxLatency = Duration(milliseconds: 800);

  static const String appName = 'AXIS Y';
  static const String currencySymbol = 'ج.م';

  /// OTP that the mock auth/reset flows accept.
  static const String mockOtp = '123456';
}
