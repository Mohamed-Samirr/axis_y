import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../config/app_config.dart';
import '../models/user.dart';
import '../network/api_client.dart';
import '../services/session_service.dart';
import '../utils/model_storage.dart';
import '../utils/result.dart';

/// Registers freshly confirmed [measurements] and stores the returned
/// `scan_id` on the session, which is what unlocks fit-check and try-on.
///
/// Deliberately silent on failure: the user's measurements are already saved
/// locally, and the try-on screen prompts for a re-scan when no scan_id exists.
Future<void> registerScanSession(
  BodyScanRepository repo,
  SessionService session,
  Measurements measurements,
) async {
  final id = (await repo.registerScan(measurements)).valueOrNull;
  if (id != null) await session.setScanId(id);
}

abstract class BodyScanRepository {
  /// Analyzes the two captured photos. The caller owns [frontImage] /
  /// [sideImage] and MUST delete them once this returns — the images are never
  /// persisted (privacy rule F4).
  Future<Result<Measurements>> analyze({
    required File frontImage,
    required File sideImage,
    required double heightCm,
  });

  /// Fetches the .glb body mesh and caches it, returning the *relative* file
  /// name under the app documents dir. A failure here must not fail the scan.
  Future<Result<String>> generateModel({
    required File frontImage,
    required File sideImage,
    required double heightCm,
  });

  /// Registers the finished scan with the main API and returns the `scan_id`
  /// that fit-check and try-on are keyed on (guide §5.3). Also non-fatal: the
  /// measurements are already the user's, this only unlocks the 3D features.
  Future<Result<String>> registerScan(Measurements measurements);
}

class ApiBodyScanRepository implements BodyScanRepository {
  final ApiClient _api;
  ApiBodyScanRepository(this._api);

  Future<FormData> _form(File front, File side, double heightCm) async => FormData.fromMap({
        'front_image': await MultipartFile.fromFile(
          front.path,
          filename: 'front.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
        'side_image': await MultipartFile.fromFile(
          side.path,
          filename: 'side.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
        'height_cm': heightCm.toString(),
      });

  @override
  Future<Result<Measurements>> analyze({
    required File frontImage,
    required File sideImage,
    required double heightCm,
  }) async {
    try {
      final res = await _api.dio.post<Map<String, dynamic>>(
        '/scan',
        data: await _form(frontImage, sideImage, heightCm),
      );
      return Success(Measurements.fromApi(res.data!));
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }

  @override
  Future<Result<String>> generateModel({
    required File frontImage,
    required File sideImage,
    required double heightCm,
  }) async {
    try {
      final res = await _api.dio.post<List<int>>(
        '/scan-3d',
        data: await _form(frontImage, sideImage, heightCm),
        options: Options(responseType: ResponseType.bytes),
      );
      final file = await ModelStorage.target();
      await file.writeAsBytes(res.data!, flush: true);
      return const Success(ModelStorage.fileName);
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }

  @override
  Future<Result<String>> registerScan(Measurements measurements) async {
    try {
      // device_id is stamped on by DeviceIdInterceptor.
      final res = await _api.dio.post<Map<String, dynamic>>(
        '${AppConfig.mainApiPrefix}/body-scan',
        data: <String, dynamic>{
          'measurements': measurements.toApiMeasurements(),
          'confidence': measurements.confidence ?? 1.0,
        },
        options: standardOptions(),
      );
      final id = res.data?['scan_id'] as String?;
      if (id == null || id.isEmpty) return const Failure('error_generic');
      return Success(id);
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }
}

/// Offline fallback. Accepts and ignores the photos, keeps the ~2.5s delay, and
/// returns the seeded measurements so the whole flow works with no backend.
class MockBodyScanRepository implements BodyScanRepository {
  @override
  Future<Result<Measurements>> analyze({
    required File frontImage,
    required File sideImage,
    required double heightCm,
  }) async {
    // Simulates 2–3s AI processing.
    await Future.delayed(const Duration(milliseconds: 2500));
    return Success(Measurements(
      chest: 92,
      waist: 78,
      hips: 100,
      height: heightCm.round(),
      weight: 74,
      shoulderCm: 44.2,
      inseamCm: 79.5,
      confidence: 0.97,
    ));
  }

  @override
  Future<Result<String>> generateModel({
    required File frontImage,
    required File sideImage,
    required double heightCm,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    // No mesh offline — the result screen falls back to the painted mannequin.
    return const Failure('scan_err_server');
  }

  @override
  Future<Result<String>> registerScan(Measurements measurements) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // A stable local id so the offline flow still has a scan to hang fit
    // checks off, matching the UUID shape the API returns.
    return Success('mock-scan-${DateTime.now().millisecondsSinceEpoch}');
  }
}
