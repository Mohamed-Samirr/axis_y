import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/user.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/repositories/body_scan_repository.dart';

enum ScanStatus { idle, analyzing, done, error }

class BodyScanState extends Equatable {
  final ScanStatus status;
  final Measurements? measurements;
  final String? error;

  const BodyScanState({this.status = ScanStatus.idle, this.measurements, this.error});

  @override
  List<Object?> get props => [status, measurements, error];
}

/// ViewModel for the mock AI body scan. Photos are never persisted — only the
/// returned measurements are saved to the user profile.
class BodyScanCubit extends Cubit<BodyScanState> {
  final BodyScanRepository _repo;
  final AuthRepository _auth;

  BodyScanCubit(this._repo, this._auth) : super(const BodyScanState());

  Future<void> analyze() async {
    emit(const BodyScanState(status: ScanStatus.analyzing));
    final result = await _repo.analyze();
    result.when(
      success: (m) => emit(BodyScanState(status: ScanStatus.done, measurements: m)),
      failure: (msg) => emit(BodyScanState(status: ScanStatus.error, error: msg)),
    );
  }

  Future<void> confirmAndSave() async {
    final m = state.measurements;
    final user = _auth.currentUser;
    if (m == null || user == null) return;
    await _auth.saveUser(user.copyWith(measurements: m));
  }
}
