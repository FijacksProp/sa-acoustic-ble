import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class SessionStore {
  static const _keyToken = 'auth_token';
  static const _keyRole = 'auth_role';
  static const _keyMatric = 'auth_matric';
  static const _keyUsername = 'auth_username';
  static const _keyFullName = 'auth_full_name';
  static const _keyDeviceId = 'device_id';
  static const _keyCurrentSessionId = 'current_session_id';

  static String? token;
  static String? role;
  static String? matricNumber;
  static String? username;
  static String? fullName;
  static String? deviceId;
  static String? currentSessionId;

  static bool get isAuthenticated => token != null && token!.isNotEmpty;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(_keyToken);
    role = prefs.getString(_keyRole);
    matricNumber = prefs.getString(_keyMatric);
    username = prefs.getString(_keyUsername);
    fullName = prefs.getString(_keyFullName);
    deviceId = prefs.getString(_keyDeviceId);
    currentSessionId = prefs.getString(_keyCurrentSessionId);
  }

  static Future<void> save({
    required String tokenValue,
    required String roleValue,
    required String matricValue,
    required String usernameValue,
    required String fullNameValue,
  }) async {
    token = tokenValue;
    role = roleValue;
    matricNumber = matricValue;
    username = usernameValue;
    fullName = fullNameValue;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, tokenValue);
    await prefs.setString(_keyRole, roleValue);
    await prefs.setString(_keyMatric, matricValue);
    await prefs.setString(_keyUsername, usernameValue);
    await prefs.setString(_keyFullName, fullNameValue);
  }

  static Future<void> clear() async {
    token = null;
    role = null;
    matricNumber = null;
    username = null;
    fullName = null;
    deviceId = null;
    currentSessionId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyRole);
    await prefs.remove(_keyMatric);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyFullName);
    await prefs.remove(_keyDeviceId);
    await prefs.remove(_keyCurrentSessionId);
  }

  static String currentIdentity() {
    final matric = matricNumber?.trim() ?? '';
    if (matric.isNotEmpty) {
      return matric;
    }
    return username?.trim() ?? '';
  }

  static Future<String> ensureDeviceId() async {
    if (deviceId != null && deviceId!.isNotEmpty) {
      return deviceId!;
    }
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_keyDeviceId);
    if (existing != null && existing.isNotEmpty) {
      deviceId = existing;
      return existing;
    }
    final generated = 'dev_${const Uuid().v4()}';
    deviceId = generated;
    await prefs.setString(_keyDeviceId, generated);
    return generated;
  }

  static Future<void> setCurrentSessionId(String? sessionId) async {
    currentSessionId = sessionId;
    final prefs = await SharedPreferences.getInstance();
    if (sessionId == null) {
      await prefs.remove(_keyCurrentSessionId);
    } else {
      await prefs.setString(_keyCurrentSessionId, sessionId);
    }
  }

  static String displayDeviceId([String? rawDeviceId]) {
    final raw = (rawDeviceId ?? deviceId ?? '').trim();
    if (raw.isEmpty) {
      return 'Not available';
    }
    final compact = raw
        .replaceFirst(RegExp(r'^dev_'), '')
        .replaceAll('-', '')
        .toUpperCase();
    final suffix = compact.length <= 8 ? compact : compact.substring(compact.length - 8);
    return 'DEV-$suffix';
  }
}
