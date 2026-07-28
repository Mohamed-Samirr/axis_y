import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Anonymous session for the AXIS Y backend (guide §3, §14).
///
/// The `device_id` is a UUID v4 minted on first launch and kept in the
/// platform keystore/keychain — it is the only identity the AI backend has, so
/// losing it orphans the user's scans. The active `scan_id` lives next to it.
class SessionService {
  static const _deviceIdKey = 'axis_device_id';
  static const _scanIdKey = 'axis_scan_id';

  final FlutterSecureStorage _storage;
  String _deviceId;
  String? _scanId;

  SessionService(this._storage, this._deviceId, this._scanId);

  static const _options = AndroidOptions(encryptedSharedPreferences: true);

  static Future<SessionService> create({FlutterSecureStorage? storage}) async {
    final store = storage ?? const FlutterSecureStorage(aOptions: _options);
    String? deviceId;
    String? scanId;
    try {
      deviceId = await store.read(key: _deviceIdKey);
      scanId = await store.read(key: _scanIdKey);
    } catch (_) {
      // A keystore that can no longer decrypt (app restored to a new device,
      // Android keystore reset) must not brick startup — mint a fresh identity.
      try {
        await store.deleteAll();
      } catch (_) {}
    }

    final session = SessionService(store, deviceId ?? _uuidV4(), scanId);
    if (deviceId == null) await session._persist(_deviceIdKey, session._deviceId);
    return session;
  }

  String get deviceId => _deviceId;

  /// Null until a scan has been registered with `POST /body-scan`. Everything
  /// fit-related (fit-check, try-on) requires it.
  String? get scanId => _scanId;
  bool get hasScan => _scanId != null && _scanId!.isNotEmpty;

  Future<void> setScanId(String id) async {
    _scanId = id;
    await _persist(_scanIdKey, id);
  }

  /// Called when the backend 404s on the stored scan — it no longer exists
  /// server-side, so the user has to re-scan (guide §12).
  Future<void> clearScan() async {
    _scanId = null;
    try {
      await _storage.delete(key: _scanIdKey);
    } catch (_) {}
  }

  /// Full reset (logout / "forget me").
  Future<void> reset() async {
    _deviceId = _uuidV4();
    _scanId = null;
    try {
      await _storage.deleteAll();
    } catch (_) {}
    await _persist(_deviceIdKey, _deviceId);
  }

  Future<void> _persist(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      // Best effort: the id stays valid in memory for this session.
    }
  }
}

/// RFC 4122 v4, from a CSPRNG. Hand-rolled to avoid a dependency for 8 lines.
String _uuidV4() {
  final rnd = Random.secure();
  final b = List<int>.generate(16, (_) => rnd.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // version 4
  b[8] = (b[8] & 0x3f) | 0x80; // variant 10x
  String hex(int from, int to) =>
      b.sublist(from, to).map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
