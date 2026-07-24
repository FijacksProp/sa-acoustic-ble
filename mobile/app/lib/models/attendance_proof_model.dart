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
    this.beaconProof = '',
    this.beaconType,
    this.beaconUuid,
    this.beaconMajor,
    this.beaconMinor,
    this.beaconNamespaceId,
    this.beaconInstanceId,
    this.beaconRssi,
    required this.rssi,
    required this.observedAt,
    required this.signature,
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
  final String beaconProof;
  final String? beaconType;
  final String? beaconUuid;
  final int? beaconMajor;
  final int? beaconMinor;
  final String? beaconNamespaceId;
  final String? beaconInstanceId;
  final int? beaconRssi;
  final int rssi;
  final DateTime observedAt;
  final String signature;
  final String? deviceTrustStatus;
  final String? deviceTrustDetail;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'session': sessionId,
      'student_id': studentId,
      'device_id': deviceId,
      'acoustic_token': acousticToken,
      'ble_nonce': bleNonce,
      'beacon_proof': beaconProof,
      'rssi': rssi,
      'observed_at': observedAt.toUtc().toIso8601String(),
      'signature': signature,
    };
    if (beaconRssi != null) {
      json['beacon_rssi'] = beaconRssi;
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
      beaconProof: json['beacon_proof'] as String? ?? '',
      beaconType: json['beacon_type'] as String?,
      beaconUuid: json['beacon_uuid'] as String?,
      beaconMajor: (json['beacon_major'] as num?)?.toInt(),
      beaconMinor: (json['beacon_minor'] as num?)?.toInt(),
      beaconNamespaceId: json['beacon_namespace_id'] as String?,
      beaconInstanceId: json['beacon_instance_id'] as String?,
      beaconRssi: (json['beacon_rssi'] as num?)?.toInt(),
      rssi: json['rssi'] as int? ?? 0,
      observedAt: DateTime.parse(json['observed_at'] as String),
      signature: json['signature'] as String? ?? '',
      deviceTrustStatus: json['device_trust_status'] as String?,
      deviceTrustDetail: json['device_trust_detail'] as String?,
    );
  }
}
