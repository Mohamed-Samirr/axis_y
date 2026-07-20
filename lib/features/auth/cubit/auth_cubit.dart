import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/repositories/auth_repository.dart';

enum AuthStatus { idle, loading, success, error }

class AuthState extends Equatable {
  final AuthStatus status;
  final String? error;
  final bool otpRequired;

  const AuthState({this.status = AuthStatus.idle, this.error, this.otpRequired = false});

  AuthState copyWith({AuthStatus? status, String? error, bool? otpRequired}) => AuthState(
        status: status ?? this.status,
        error: error,
        otpRequired: otpRequired ?? this.otpRequired,
      );

  @override
  List<Object?> get props => [status, error, otpRequired];
}

/// ViewModel for register / login / OTP flows.
class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repo;

  AuthCubit(this._repo) : super(const AuthState());

  Future<void> register({required String name, required String phoneOrEmail, required String password}) async {
    emit(state.copyWith(status: AuthStatus.loading, error: null));
    final result = await _repo.register(name: name, phoneOrEmail: phoneOrEmail, password: password);
    result.when(
      success: (_) => emit(state.copyWith(status: AuthStatus.success, otpRequired: true)),
      failure: (m) => emit(state.copyWith(status: AuthStatus.error, error: m)),
    );
  }

  Future<void> login({required String phoneOrEmail, required String password}) async {
    emit(state.copyWith(status: AuthStatus.loading, error: null));
    final result = await _repo.login(phoneOrEmail: phoneOrEmail, password: password);
    result.when(
      success: (_) => emit(state.copyWith(status: AuthStatus.success)),
      failure: (m) => emit(state.copyWith(status: AuthStatus.error, error: m)),
    );
  }

  Future<void> verifyOtp(String otp) async {
    emit(state.copyWith(status: AuthStatus.loading, error: null));
    final result = await _repo.verifyOtp(otp);
    result.when(
      success: (_) => emit(state.copyWith(status: AuthStatus.success)),
      failure: (m) => emit(state.copyWith(status: AuthStatus.error, error: m)),
    );
  }

  Future<void> google() async {
    emit(state.copyWith(status: AuthStatus.loading, error: null));
    final r = await _repo.loginWithGoogle();
    r.when(
      success: (_) => emit(state.copyWith(status: AuthStatus.success)),
      failure: (m) => emit(state.copyWith(status: AuthStatus.error, error: m)),
    );
  }

  Future<void> apple() async {
    emit(state.copyWith(status: AuthStatus.loading, error: null));
    final r = await _repo.loginWithApple();
    r.when(
      success: (_) => emit(state.copyWith(status: AuthStatus.success)),
      failure: (m) => emit(state.copyWith(status: AuthStatus.error, error: m)),
    );
  }

  void reset() => emit(const AuthState());
}
