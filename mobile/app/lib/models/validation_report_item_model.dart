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
  });

  final int proofId;
  final int sessionId;
  final String studentId;
  final String status;
  final List<String> passedChecks;
  final List<String> failedChecks;
  final int? acousticAgeSeconds;
  final int? bleAgeSeconds;

  factory ValidationReportItemModel.fromJson(Map<String, dynamic> json) {
    return ValidationReportItemModel(
      proofId: (json['proof_id'] as num?)?.toInt() ?? 0,
      sessionId: (json['session_id'] as num?)?.toInt() ?? 0,
      studentId: json['student_id']?.toString() ?? '',
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
