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
    String? faceImageBase64,
  }) async {
    final deviceId = await SessionStore.ensureDeviceId();
    final payload = <String, dynamic>{
      'full_name': fullName,
      'role': role,
      'password': password,
      'device_id': deviceId,
    };
    if (matricNumber != null && matricNumber.trim().isNotEmpty) {
      payload['matric_number'] = matricNumber.trim();
    }
    if (username != null && username.trim().isNotEmpty) {
      payload['username'] = username.trim();
    }
    if (faceImageBase64 != null && faceImageBase64.trim().isNotEmpty) {
      payload['face_image_base64'] = faceImageBase64.trim();
    }

    final response = await _client.postJson('/api/auth/register/', payload);
    await _storeAuth(response);
    return response;
  }

  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    final deviceId = await SessionStore.ensureDeviceId();
    final response = await _client.postJson('/api/auth/login/', {
      'identifier': identifier,
      'password': password,
      'device_id': deviceId,
    });
    await _storeAuth(response);
    return response;
  }

  Future<void> logout() async {
    await SessionStore.clear();
  }

  Future<Map<String, dynamic>> getCurrentProfile() async {
    final response = await _client.getMap('/api/auth/me/');
    await SessionStore.setHasFaceEnrollment(
      response['has_face_enrollment'] == true,
    );
    await SessionStore.setRegisteredDeviceId(
      response['registered_device_id']?.toString() ?? '',
    );
    return response;
  }

  Future<void> enrollFace(String faceImageBase64) async {
    final response = await _client.postJson('/api/auth/face-enrollment/', {
      'face_image_base64': faceImageBase64.trim(),
    });
    await SessionStore.setHasFaceEnrollment(
      response['has_face_enrollment'] == true,
    );
  }

  Future<void> _storeAuth(Map<String, dynamic> payload) async {
    final token = payload['token']?.toString() ?? '';
    final role = payload['role']?.toString() ?? '';
    final matric = payload['matric_number']?.toString() ?? '';
    final username = payload['username']?.toString() ?? '';
    final fullName = payload['full_name']?.toString() ?? '';
    final hasFaceEnrollment = payload['has_face_enrollment'] == true;
    final registeredDeviceId = payload['registered_device_id']?.toString() ?? '';
    await SessionStore.save(
      tokenValue: token,
      roleValue: role,
      matricValue: matric,
      usernameValue: username,
      fullNameValue: fullName,
      hasFaceEnrollmentValue: hasFaceEnrollment,
      registeredDeviceIdValue: registeredDeviceId,
    );
  }
}
