import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class SessionStore {
  static const _keyToken = 'auth_token';
  static const _keyRole = 'auth_role';
  static const _keyMatric = 'auth_matric';
  static const _keyUsername = 'auth_username';
  static const _keyDeviceId = 'device_id';

  static String? token;
  static String? role;
  static String? matricNumber;
  static String? username;
  static String? deviceId;

  static bool get isAuthenticated => token != null && token!.isNotEmpty;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(_keyToken);
    role = prefs.getString(_keyRole);
    matricNumber = prefs.getString(_keyMatric);
    username = prefs.getString(_keyUsername);
    deviceId = prefs.getString(_keyDeviceId);
  }

  static Future<void> save({
    required String tokenValue,
    required String roleValue,
    required String matricValue,
    required String usernameValue,
  }) async {
    token = tokenValue;
    role = roleValue;
    matricNumber = matricValue;
    username = usernameValue;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, tokenValue);
    await prefs.setString(_keyRole, roleValue);
    await prefs.setString(_keyMatric, matricValue);
    await prefs.setString(_keyUsername, usernameValue);
  }

  static Future<void> clear() async {
    token = null;
    role = null;
    matricNumber = null;
    username = null;
    deviceId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyRole);
    await prefs.remove(_keyMatric);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyDeviceId);
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
}
