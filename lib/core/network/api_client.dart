import 'package:dio/dio.dart';

import '../config/app_config.dart';

/// Thin dio wrapper for the AXIS Y backend.
///
/// Deliberately has **no logging interceptor**: request bodies carry the user's
/// body photos and must never be printed to the console.
class ApiClient {
  final Dio dio;

  ApiClient()
      : dio = Dio(BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: AppConfig.connectTimeout,
          receiveTimeout: AppConfig.scanTimeout,
          sendTimeout: AppConfig.scanTimeout,
        ));
}

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
  if (status != null && status >= 500) return 'scan_err_server';
  return 'error_generic';
}
