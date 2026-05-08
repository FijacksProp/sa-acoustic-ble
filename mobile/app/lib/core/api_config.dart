import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  // For Android emulator use 10.0.2.2. For real device use your LAN IP.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static const _keyRuntimeBaseUrl = 'runtime_api_base_url';

  static String? _runtimeBaseUrl;

  static String get currentBaseUrl {
    final runtime = _runtimeBaseUrl?.trim() ?? '';
    if (runtime.isNotEmpty) {
      return runtime;
    }
    return baseUrl;
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _runtimeBaseUrl = prefs.getString(_keyRuntimeBaseUrl);
  }

  static Future<void> setRuntimeBaseUrl(String value) async {
    final normalized = normalizeBaseUrl(value);
    _runtimeBaseUrl = normalized;
    final prefs = await SharedPreferences.getInstance();
    if (normalized.isEmpty) {
      await prefs.remove(_keyRuntimeBaseUrl);
    } else {
      await prefs.setString(_keyRuntimeBaseUrl, normalized);
    }
  }

  static String normalizeBaseUrl(String value) {
    var cleaned = value.trim();
    while (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    return cleaned;
  }
}
