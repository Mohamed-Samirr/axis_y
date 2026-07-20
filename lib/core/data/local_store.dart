import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper over SharedPreferences for local persistence (session, cart,
/// wishlist, measurements, points, orders) so state survives restarts with no
/// server.
class LocalStore {
  final SharedPreferences _prefs;
  LocalStore(this._prefs);

  static Future<LocalStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStore(prefs);
  }

  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) => _prefs.setString(key, value);

  bool getBool(String key, {bool fallback = false}) => _prefs.getBool(key) ?? fallback;
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  Map<String, dynamic>? getJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> setJson(String key, Map<String, dynamic> value) =>
      _prefs.setString(key, jsonEncode(value));

  List<dynamic>? getJsonList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    return jsonDecode(raw) as List<dynamic>;
  }

  Future<void> setJsonList(String key, List<dynamic> value) =>
      _prefs.setString(key, jsonEncode(value));

  Future<void> remove(String key) => _prefs.remove(key);
}

abstract class StoreKeys {
  static const session = 'session_user';
  static const onboardingDone = 'onboarding_done';
  static const wishlist = 'wishlist_ids';
  static const cart = 'cart_items';
  static const orders = 'orders';
  static const locale = 'locale';
  static const preferences = 'style_prefs';
}
