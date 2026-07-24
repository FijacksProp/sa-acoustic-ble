import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://sa-acoustic-ble.onrender.com',
  );

  static const _keyRuntimeBaseUrl = 'runtime_api_base_url';

  static String get currentBaseUrl => normalizeBaseUrl(baseUrl);

  static Future<void> load() async {
    // Remove overrides saved by early LAN builds. The hosted endpoint or
    // --dart-define is now the single source of truth.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRuntimeBaseUrl);
  }

  static String normalizeBaseUrl(String value) {
    var cleaned = value.trim();
    while (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    return cleaned;
  }
}
