import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../services/session_service.dart';

/// Thin dio wrapper for the AXIS Y backend.
///
/// Deliberately has **no logging interceptor**: request bodies carry the user's
/// body photos and must never be printed to the console.
class ApiClient {
  final Dio dio;

  ApiClient(SessionService session)
      : dio = Dio(BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: AppConfig.connectTimeout,
          // Per-request overrides ([standardOptions], [tryOnOptions]) tighten
          // this; the scan upload is the slowest call so it sets the default.
          receiveTimeout: AppConfig.scanTimeout,
          sendTimeout: AppConfig.scanTimeout,
        )) {
    dio.interceptors.add(DeviceIdInterceptor(session));
    dio.interceptors.add(RetryInterceptor(dio));
  }
}

/// Stamps the anonymous session onto every request (guide §9).
///
/// The header covers endpoints that read it from there; JSON bodies also get a
/// `device_id` field when they don't already carry one, so callers never have
/// to remember it. Multipart bodies are left alone — the scan endpoints take
/// their fields explicitly.
class DeviceIdInterceptor extends Interceptor {
  static const header = 'X-Device-Id';
  final SessionService _session;

  DeviceIdInterceptor(this._session);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers[header] = _session.deviceId;
    final data = options.data;
    if (data is Map<String, dynamic> && !data.containsKey('device_id')) {
      data['device_id'] = _session.deviceId;
    }
    handler.next(options);
  }
}

/// Exponential backoff for 5xx and transport failures.
///
/// Never retries 4xx: a 422 is a low-confidence scan or a bad payload, and
/// replaying it just burns the user's time. Multipart uploads are also skipped
/// — their stream is consumed on the first attempt, and re-sending two photos
/// on a mobile connection costs more than it saves.
class RetryInterceptor extends Interceptor {
  static const _attemptKey = 'axis_retry_attempt';
  final Dio _dio;

  RetryInterceptor(this._dio);

  bool _shouldRetry(DioException err) {
    if (err.requestOptions.data is FormData) return false;
    switch (err.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
        return true;
      case DioExceptionType.badResponse:
        final status = err.response?.statusCode ?? 0;
        return status >= 500;
      default:
        return false;
    }
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final attempt = (err.requestOptions.extra[_attemptKey] as int?) ?? 0;
    if (attempt >= AppConfig.maxRetries || !_shouldRetry(err)) {
      return handler.next(err);
    }

    await Future<void>.delayed(AppConfig.retryBaseDelay * (1 << attempt));
    final options = err.requestOptions..extra[_attemptKey] = attempt + 1;
    try {
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}

/// Timeouts for the light JSON endpoints (products, fit-check, /body-scan).
Options standardOptions() => Options(
      receiveTimeout: AppConfig.standardTimeout,
      sendTimeout: AppConfig.standardTimeout,
    );

/// Try-on morphs on the server before responding (guide §9).
Options tryOnOptions() => Options(
      receiveTimeout: AppConfig.tryOnTimeout,
      sendTimeout: AppConfig.tryOnTimeout,
    );

/// Maps a [DioException] to an `AppStrings` key so the UI stays localized and
/// no raw server text is shown to the user.
String mapDioError(Object error) {
  if (error is! DioException) return 'error_generic';

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.connectionError:
      return 'scan_err_offline';
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.sendTimeout:
      return 'scan_err_timeout';
    default:
      break;
  }

  final status = error.response?.statusCode;
  final detail = error.response?.data;

  if (status == 422 && detail is Map && detail['detail'] is String) {
    final d = detail['detail'] as String;
    if (d.contains('front image')) return 'scan_err_no_person_front';
    if (d.contains('side image')) return 'scan_err_no_person_side';
    if (d.contains('height_cm')) return 'scan_err_bad_height';
  }
  // 422 with a List detail = a malformed request we built. Client bug.
  if (status == 422) return 'scan_err_bad_request';
  // The scan the request referenced is gone server-side; the caller drops the
  // stored scan_id and sends the user back to scanning (guide §12).
  if (status == 404) return 'err_scan_missing';
  if (status != null && status >= 500) return 'scan_err_server';
  return 'error_generic';
}

/// True when the failure means the stored `scan_id` is no longer valid.
bool isMissingScan(Object error) =>
    error is DioException && error.response?.statusCode == 404;
