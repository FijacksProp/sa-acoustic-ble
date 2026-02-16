class ScanResultModel {
  ScanResultModel({
    required this.acousticToken,
    required this.observedAt,
    this.bleNonce,
    this.rssi,
    this.sessionId,
    this.tokenVersion,
    this.issuedAt,
  });

  final String acousticToken;
  final DateTime observedAt;
  final String? bleNonce;
  final int? rssi;
  final int? sessionId;
  final String? tokenVersion;
  final DateTime? issuedAt;

  factory ScanResultModel.fromMap(Map<Object?, Object?> map) {
    final observed = map['observedAt']?.toString();
    return ScanResultModel(
      acousticToken: map['acousticToken']?.toString() ?? '',
      observedAt: observed == null
          ? DateTime.now().toUtc()
          : DateTime.parse(observed).toUtc(),
      bleNonce: map['bleNonce']?.toString(),
      rssi: map['rssi'] is int ? map['rssi'] as int : int.tryParse('${map['rssi']}'),
      sessionId: map['sessionId'] is int
          ? map['sessionId'] as int
          : int.tryParse('${map['sessionId']}'),
      tokenVersion: map['tokenVersion']?.toString(),
      issuedAt: map['issuedAt'] == null
          ? null
          : DateTime.tryParse(map['issuedAt'].toString())?.toUtc(),
    );
  }
}
