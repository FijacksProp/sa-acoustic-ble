class ScanTestLogModel {
  ScanTestLogModel({
    required this.recordedAt,
    required this.trustSummary,
    required this.acousticSource,
    required this.bleSource,
    required this.acousticDiagnostic,
    required this.bleDiagnostic,
    required this.decodedSessionId,
    required this.signalAgeSeconds,
    required this.rssi,
    required this.passedChecks,
    required this.failedChecks,
  });

  final DateTime recordedAt;
  final String trustSummary;
  final String acousticSource;
  final String bleSource;
  final String acousticDiagnostic;
  final String bleDiagnostic;
  final int? decodedSessionId;
  final int? signalAgeSeconds;
  final int? rssi;
  final List<String> passedChecks;
  final List<String> failedChecks;

  bool get isSuccessful => failedChecks.isEmpty;

  Map<String, dynamic> toJson() {
    return {
      'recorded_at': recordedAt.toUtc().toIso8601String(),
      'trust_summary': trustSummary,
      'acoustic_source': acousticSource,
      'ble_source': bleSource,
      'acoustic_diagnostic': acousticDiagnostic,
      'ble_diagnostic': bleDiagnostic,
      'decoded_session_id': decodedSessionId,
      'signal_age_seconds': signalAgeSeconds,
      'rssi': rssi,
      'passed_checks': passedChecks,
      'failed_checks': failedChecks,
    };
  }

  factory ScanTestLogModel.fromJson(Map<String, dynamic> json) {
    return ScanTestLogModel(
      recordedAt: DateTime.tryParse(json['recorded_at']?.toString() ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      trustSummary: json['trust_summary']?.toString() ?? '',
      acousticSource: json['acoustic_source']?.toString() ?? '',
      bleSource: json['ble_source']?.toString() ?? '',
      acousticDiagnostic: json['acoustic_diagnostic']?.toString() ?? '',
      bleDiagnostic: json['ble_diagnostic']?.toString() ?? '',
      decodedSessionId: (json['decoded_session_id'] as num?)?.toInt(),
      signalAgeSeconds: (json['signal_age_seconds'] as num?)?.toInt(),
      rssi: (json['rssi'] as num?)?.toInt(),
      passedChecks: (json['passed_checks'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      failedChecks: (json['failed_checks'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}
