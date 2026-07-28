import 'package:axis_y/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _withResponse(int status, dynamic data) {
  final options = RequestOptions(path: '/scan');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: options, statusCode: status, data: data),
  );
}

DioException _ofType(DioExceptionType type) =>
    DioException(requestOptions: RequestOptions(path: '/scan'), type: type);

void main() {
  group('mapDioError', () {
    test('maps connection failures to the offline key', () {
      expect(mapDioError(_ofType(DioExceptionType.connectionTimeout)), 'scan_err_offline');
      expect(mapDioError(_ofType(DioExceptionType.connectionError)), 'scan_err_offline');
    });

    test('maps send/receive timeouts to the timeout key', () {
      expect(mapDioError(_ofType(DioExceptionType.receiveTimeout)), 'scan_err_timeout');
      expect(mapDioError(_ofType(DioExceptionType.sendTimeout)), 'scan_err_timeout');
    });

    test('distinguishes the front and side no-person 422s', () {
      expect(
        mapDioError(_withResponse(422, {'detail': 'No person detected in the front image.'})),
        'scan_err_no_person_front',
      );
      expect(
        mapDioError(_withResponse(422, {'detail': 'No person detected in the side image.'})),
        'scan_err_no_person_side',
      );
    });

    test('maps the height validation 422', () {
      expect(
        mapDioError(_withResponse(422, {'detail': 'height_cm must be between 100 and 250.'})),
        'scan_err_bad_height',
      );
    });

    test('survives a 422 whose detail is a Pydantic list, not a string', () {
      final detail = {
        'detail': [
          {'loc': ['body', 'height_cm'], 'msg': 'field required', 'type': 'value_error.missing'},
        ],
      };
      expect(mapDioError(_withResponse(422, detail)), 'scan_err_bad_request');
    });

    test('maps 404 to the missing-scan key so the app can drop the scan_id', () {
      final error = _withResponse(404, {'detail': 'Scan not found'});
      expect(mapDioError(error), 'err_scan_missing');
      expect(isMissingScan(error), isTrue);
      expect(isMissingScan(_withResponse(500, null)), isFalse);
    });

    test('maps 5xx to the server key', () {
      expect(mapDioError(_withResponse(500, {'detail': 'Internal error: boom'})), 'scan_err_server');
      expect(mapDioError(_withResponse(503, null)), 'scan_err_server');
    });

    test('falls back to the generic key for non-dio errors', () {
      expect(mapDioError(Exception('something else')), 'error_generic');
    });

    test('never leaks raw server text', () {
      final key = mapDioError(_withResponse(500, {'detail': 'Internal error: /srv/secret/path.py'}));
      expect(key, isNot(contains('secret')));
      expect(key, 'scan_err_server');
    });
  });
}
