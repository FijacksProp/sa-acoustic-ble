class ValidationReportItemModel {
  ValidationReportItemModel({
    required this.proofId,
    required this.sessionId,
    required this.studentId,
    required this.status,
    required this.passedChecks,
    required this.failedChecks,
    this.acousticAgeSeconds,
    this.bleAgeSeconds,
    this.studentName,
    this.courseCode,
    this.courseTitle,
    this.lecturerName,
    this.room,
    this.beaconProof,
  });

  final int proofId;
  final int sessionId;
  final String studentId;
  final String status;
  final List<String> passedChecks;
  final List<String> failedChecks;
  final int? acousticAgeSeconds;
  final int? bleAgeSeconds;
  final String? studentName;
  final String? courseCode;
  final String? courseTitle;
  final String? lecturerName;
  final String? room;
  final String? beaconProof;

  factory ValidationReportItemModel.fromJson(Map<String, dynamic> json) {
    return ValidationReportItemModel(
      proofId: (json['proof_id'] as num?)?.toInt() ?? 0,
      sessionId: (json['session_id'] as num?)?.toInt() ?? 0,
      studentId: json['student_id']?.toString() ?? '',
      studentName: json['student_name']?.toString(),
      courseCode: json['course_code']?.toString(),
      courseTitle: json['course_title']?.toString(),
      lecturerName: json['lecturer_name']?.toString(),
      room: json['room']?.toString(),
      beaconProof: json['beacon_proof']?.toString(),
      status: json['status']?.toString() ?? 'fail',
      passedChecks: (json['passed_checks'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      failedChecks: (json['failed_checks'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      acousticAgeSeconds: (json['acoustic_age_seconds'] as num?)?.toInt(),
      bleAgeSeconds: (json['ble_age_seconds'] as num?)?.toInt(),
    );
  }
}
