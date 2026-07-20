import '../config/app_config.dart';
import '../data/local_store.dart';
import '../data/mock_seed.dart';
import '../models/user.dart';
import '../utils/latency.dart';
import '../utils/result.dart';

abstract class AuthRepository {
  AppUser? get currentUser;
  bool get isLoggedIn;

  Future<Result<AppUser>> register({required String name, required String phoneOrEmail, required String password});
  Future<Result<AppUser>> login({required String phoneOrEmail, required String password});
  Future<Result<void>> verifyOtp(String otp);
  Future<void> logout();
  Future<void> saveUser(AppUser user);

  // Social sign-in stubs (wired to real OAuth later).
  Future<Result<AppUser>> loginWithGoogle();
  Future<Result<AppUser>> loginWithApple();
}

class MockAuthRepository implements AuthRepository {
  final LocalStore _store;
  AppUser? _current;

  MockAuthRepository(this._store) {
    final json = _store.getJson(StoreKeys.session);
    if (json != null) _current = AppUser.fromJson(json);
  }

  @override
  AppUser? get currentUser => _current;

  @override
  bool get isLoggedIn => _current != null;

  @override
  Future<Result<AppUser>> register({
    required String name,
    required String phoneOrEmail,
    required String password,
  }) async {
    await mockLatency();
    // Account is created but session is saved only after OTP verification.
    _current = AppUser(
      id: 'u${DateTime.now().millisecondsSinceEpoch}',
      name: name.isEmpty ? 'مستخدم AXIS' : name,
      phoneOrEmail: phoneOrEmail,
      points: 0,
    );
    return Success(_current!);
  }

  @override
  Future<Result<AppUser>> login({required String phoneOrEmail, required String password}) async {
    await mockLatency();
    // Mock: any credentials pass; hydrate with the seeded demo profile.
    _current = MockSeed.defaultUser;
    await saveUser(_current!);
    return Success(_current!);
  }

  @override
  Future<Result<void>> verifyOtp(String otp) async {
    await mockLatency();
    if (otp.trim() != AppConfig.mockOtp) {
      return const Failure('otp_wrong');
    }
    if (_current != null) await saveUser(_current!);
    return const Success(null);
  }

  @override
  Future<void> logout() async {
    _current = null;
    await _store.remove(StoreKeys.session);
  }

  @override
  Future<void> saveUser(AppUser user) async {
    _current = user;
    await _store.setJson(StoreKeys.session, user.toJson());
  }

  @override
  Future<Result<AppUser>> loginWithGoogle() async {
    await mockLatency();
    _current = MockSeed.defaultUser;
    await saveUser(_current!);
    return Success(_current!);
  }

  @override
  Future<Result<AppUser>> loginWithApple() async {
    await mockLatency();
    _current = MockSeed.defaultUser;
    await saveUser(_current!);
    return Success(_current!);
  }
}
