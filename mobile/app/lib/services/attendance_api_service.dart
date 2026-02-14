import '../core/api_client.dart';
import '../models/attendance_proof_model.dart';
import '../models/session_model.dart';

class AttendanceApiService {
  AttendanceApiService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<SessionModel> createSession(SessionModel session) async {
    final json = await _client.postJson('/api/sessions/', session.toJson());
    return SessionModel.fromJson(json);
  }

  Future<List<SessionModel>> listSessions() async {
    final list = await _client.getList('/api/sessions/');
    return list
        .cast<Map<String, dynamic>>()
        .map(SessionModel.fromJson)
        .toList();
  }

  Future<AttendanceProofModel> submitProof(AttendanceProofModel proof) async {
    final json = await _client.postJson('/api/attendance/', proof.toJson());
    return AttendanceProofModel.fromJson(json);
  }
}
