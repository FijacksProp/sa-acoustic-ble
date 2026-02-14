class AttendanceProofModel {
  AttendanceProofModel({
    this.id,
    required this.sessionId,
    required this.studentId,
    required this.deviceId,
    required this.acousticToken,
    required this.bleNonce,
    required this.rssi,
    required this.observedAt,
    required this.signature,
  });

  final int? id;
  final int sessionId;
  final String studentId;
  final String deviceId;
  final String acousticToken;
  final String bleNonce;
  final int rssi;
  final DateTime observedAt;
  final String signature;

  Map<String, dynamic> toJson() {
    return {
      'session': sessionId,
      'student_id': studentId,
      'device_id': deviceId,
      'acoustic_token': acousticToken,
      'ble_nonce': bleNonce,
      'rssi': rssi,
      'observed_at': observedAt.toUtc().toIso8601String(),
      'signature': signature,
    };
  }

  factory AttendanceProofModel.fromJson(Map<String, dynamic> json) {
    return AttendanceProofModel(
      id: json['id'] as int?,
      sessionId: json['session'] as int,
      studentId: json['student_id'] as String? ?? '',
      deviceId: json['device_id'] as String? ?? '',
      acousticToken: json['acoustic_token'] as String? ?? '',
      bleNonce: json['ble_nonce'] as String? ?? '',
      rssi: json['rssi'] as int? ?? 0,
      observedAt: DateTime.parse(json['observed_at'] as String),
      signature: json['signature'] as String? ?? '',
    );
  }
}
