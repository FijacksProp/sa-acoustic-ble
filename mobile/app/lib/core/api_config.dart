import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://sas-z5iu.onrender.com',
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
    if (_isLocalDevelopmentUrl(_runtimeBaseUrl)) {
      _runtimeBaseUrl = null;
      await prefs.remove(_keyRuntimeBaseUrl);
    }
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

  static bool _isLocalDevelopmentUrl(String? value) {
    final cleaned = normalizeBaseUrl(value ?? '').toLowerCase();
    if (cleaned.isEmpty) {
      return false;
    }
    if (cleaned.contains('localhost') ||
        cleaned.contains('127.0.0.1') ||
        cleaned.contains('10.0.2.2')) {
      return true;
    }
    final uri = Uri.tryParse(cleaned);
    final host = uri?.host;
    if (host == null || host.isEmpty) {
      return false;
    }
    return host.startsWith('10.') ||
        host.startsWith('192.168.') ||
        RegExp(r'^172\.(1[6-9]|2\d|3[0-1])\.').hasMatch(host);
  }
}
