import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/scan_analysis.dart';
import '../../../core/models/user.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/repositories/body_scan_repository.dart';
import '../../../core/services/session_service.dart';
import '../models/scan_input.dart';

enum ScanStatus { idle, uploading, analyzing, buildingModel, done, error }

class BodyScanState extends Equatable {
  final ScanStatus status;
  final Measurements? measurements;
  final String? error;

  /// Decoded debug frames from the pipeline, present only when the build asked
  /// for them ([AppConfig.requestAnnotatedScan]). Display-only, never saved.
  final Uint8List? annotatedFront;
  final Uint8List? annotatedSide;

  const BodyScanState({
    this.status = ScanStatus.idle,
    this.measurements,
    this.error,
    this.annotatedFront,
    this.annotatedSide,
  });

  bool get isBusy =>
      status == ScanStatus.idle ||
      status == ScanStatus.uploading ||
      status == ScanStatus.analyzing ||
      status == ScanStatus.buildingModel;

  @override
  List<Object?> get props => [status, measurements, error, annotatedFront, annotatedSide];
}

/// ViewModel for the body scan. Photos are never persisted — they are deleted
/// as soon as the request settles, whatever the outcome (privacy rule F4).
class BodyScanCubit extends Cubit<BodyScanState> {
  final BodyScanRepository _repo;
  final AuthRepository _auth;
  final SessionService _session;

  BodyScanCubit(this._repo, this._auth, this._session) : super(const BodyScanState());

  /// Guarded emit: the user may leave the screen while a 30s request is still
  /// in flight, which closes the Cubit.
  void _safeEmit(BodyScanState state) {
    if (!isClosed) emit(state);
  }

  Future<void> analyze(ScanInput input) async {
    final front = input.front;
    final side = input.side;
    if (front == null || side == null) {
      _safeEmit(const BodyScanState(status: ScanStatus.error, error: 'scan_err_bad_request'));
      return;
    }

    _safeEmit(const BodyScanState(status: ScanStatus.uploading));
    try {
      final result = await _repo.analyze(
        frontImage: front,
        sideImage: side,
        heightCm: input.heightCm,
      );
      await result.when(
        success: (analysis) async {
          // The API only ever *estimates* weight from the photos — if the user
          // told us theirs on the intro screen, that is the better number.
          final m = input.weightKg == null
              ? analysis.measurements
              : analysis.measurements.copyWith(weight: input.weightKg!.round());
          _safeEmit(_stateFor(ScanStatus.buildingModel, m, analysis));
          final model = await _repo.generateModel(
            frontImage: front,
            sideImage: side,
            heightCm: input.heightCm,
          );
          // A missing 3D model is not a scan failure — the result screen falls
          // back to the painted mannequin. Measurements are the product.
          _safeEmit(_stateFor(
            ScanStatus.done,
            m.copyWith(modelPath: model.valueOrNull),
            analysis,
          ));
        },
        failure: (msg) async => _safeEmit(BodyScanState(status: ScanStatus.error, error: msg)),
      );
    } finally {
      // Delete in `finally`, not on the success path: an error or the user
      // backing out must still wipe the photos.
      await _safeDelete(front);
      await _safeDelete(side);
    }
  }

  /// Keeps the annotated frames attached across the two success emits — they
  /// come with the measurements but must survive the 3D-model step.
  BodyScanState _stateFor(ScanStatus status, Measurements m, ScanAnalysis analysis) => BodyScanState(
        status: status,
        measurements: m,
        annotatedFront: analysis.annotatedFront,
        annotatedSide: analysis.annotatedSide,
      );

  Future<void> _safeDelete(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {
      // Best effort.
    }
  }

  Future<void> confirmAndSave() async {
    final m = state.measurements;
    final user = _auth.currentUser;
    if (m == null || user == null) return;
    await _auth.saveUser(user.copyWith(measurements: m));
    // Not awaited: the profile is already saved and navigation must not wait on
    // the gateway. The scan_id lands before the user reaches a product page.
    unawaited(registerScanSession(_repo, _session, m));
  }
}
