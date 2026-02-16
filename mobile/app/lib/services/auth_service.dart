import '../core/api_client.dart';
import '../core/session_store.dart';

class AuthService {
  AuthService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<Map<String, dynamic>> register({
    required String fullName,
    String? matricNumber,
    String? username,
    required String role,
    required String password,
  }) async {
    final payload = <String, dynamic>{
      'full_name': fullName,
      'role': role,
      'password': password,
    };
    if (matricNumber != null && matricNumber.trim().isNotEmpty) {
      payload['matric_number'] = matricNumber.trim();
    }
    if (username != null && username.trim().isNotEmpty) {
      payload['username'] = username.trim();
    }

    final response = await _client.postJson('/api/auth/register/', payload);
    await _storeAuth(response);
    return response;
  }

  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _client.postJson('/api/auth/login/', {
      'identifier': identifier,
      'password': password,
    });
    await _storeAuth(response);
    return response;
  }

  Future<void> logout() async {
    await SessionStore.clear();
  }

  Future<void> _storeAuth(Map<String, dynamic> payload) async {
    final token = payload['token']?.toString() ?? '';
    final role = payload['role']?.toString() ?? '';
    final matric = payload['matric_number']?.toString() ?? '';
    final username = payload['username']?.toString() ?? '';
    await SessionStore.save(
      tokenValue: token,
      roleValue: role,
      matricValue: matric,
      usernameValue: username,
    );
  }
}
