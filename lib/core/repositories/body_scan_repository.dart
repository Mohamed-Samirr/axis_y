import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../models/user.dart';
import '../network/api_client.dart';
import '../utils/model_storage.dart';
import '../utils/result.dart';

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
}
