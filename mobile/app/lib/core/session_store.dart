import 'package:shared_preferences/shared_preferences.dart';

class SessionStore {
  static const _keyToken = 'auth_token';
  static const _keyRole = 'auth_role';
  static const _keyMatric = 'auth_matric';

  static String? token;
  static String? role;
  static String? matricNumber;

  static bool get isAuthenticated => token != null && token!.isNotEmpty;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(_keyToken);
    role = prefs.getString(_keyRole);
    matricNumber = prefs.getString(_keyMatric);
  }

  static Future<void> save({
    required String tokenValue,
    required String roleValue,
    required String matricValue,
  }) async {
    token = tokenValue;
    role = roleValue;
    matricNumber = matricValue;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, tokenValue);
    await prefs.setString(_keyRole, roleValue);
    await prefs.setString(_keyMatric, matricValue);
  }

  static Future<void> clear() async {
    token = null;
    role = null;
    matricNumber = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyRole);
    await prefs.remove(_keyMatric);
  }
}
