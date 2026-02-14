class ApiConfig {
  // For Android emulator use 10.0.2.2. For real device use your LAN IP.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
}
