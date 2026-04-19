class AttendanceProofModel {
  AttendanceProofModel({
    this.id,
    required this.sessionId,
    required this.studentId,
    this.studentName,
    this.courseCode,
    this.courseTitle,
    this.lecturerName,
    this.room,
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
  final String? studentName;
  final String? courseCode;
  final String? courseTitle;
  final String? lecturerName;
  final String? room;
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
      studentName: json['student_name'] as String?,
      courseCode: json['course_code'] as String?,
      courseTitle: json['course_title'] as String?,
      lecturerName: json['lecturer_name'] as String?,
      room: json['room'] as String?,
      deviceId: json['device_id'] as String? ?? '',
      acousticToken: json['acoustic_token'] as String? ?? '',
      bleNonce: json['ble_nonce'] as String? ?? '',
      rssi: json['rssi'] as int? ?? 0,
      observedAt: DateTime.parse(json['observed_at'] as String),
      signature: json['signature'] as String? ?? '',
    );
  }
}
