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
    this.wifiProof = '',
    this.wifiClientIp,
    required this.rssi,
    required this.observedAt,
    required this.signature,
    this.attendanceFaceImageBase64,
    this.faceVerificationStatus,
    this.faceMatchScore,
    this.deviceTrustStatus,
    this.deviceTrustDetail,
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
  final String wifiProof;
  final String? wifiClientIp;
  final int rssi;
  final DateTime observedAt;
  final String signature;
  final String? attendanceFaceImageBase64;
  final String? faceVerificationStatus;
  final double? faceMatchScore;
  final String? deviceTrustStatus;
  final String? deviceTrustDetail;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'session': sessionId,
      'student_id': studentId,
      'device_id': deviceId,
      'acoustic_token': acousticToken,
      'ble_nonce': bleNonce,
      'wifi_proof': wifiProof,
      'rssi': rssi,
      'observed_at': observedAt.toUtc().toIso8601String(),
      'signature': signature,
    };
    if ((attendanceFaceImageBase64 ?? '').trim().isNotEmpty) {
      json['attendance_face_image_base64'] = attendanceFaceImageBase64!.trim();
    }
    if ((faceVerificationStatus ?? '').trim().isNotEmpty) {
      json['face_verification_status'] = faceVerificationStatus!.trim();
    }
    if (faceMatchScore != null) {
      json['face_match_score'] = faceMatchScore;
    }
    return json;
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
      wifiProof: json['wifi_proof'] as String? ?? '',
      wifiClientIp: json['wifi_client_ip'] as String?,
      rssi: json['rssi'] as int? ?? 0,
      observedAt: DateTime.parse(json['observed_at'] as String),
      signature: json['signature'] as String? ?? '',
      attendanceFaceImageBase64:
          json['attendance_face_image_base64'] as String?,
      faceVerificationStatus: json['face_verification_status'] as String?,
      faceMatchScore: (json['face_match_score'] as num?)?.toDouble(),
      deviceTrustStatus: json['device_trust_status'] as String?,
      deviceTrustDetail: json['device_trust_detail'] as String?,
    );
  }
}
