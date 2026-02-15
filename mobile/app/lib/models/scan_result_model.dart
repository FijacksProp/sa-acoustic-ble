class ScanResultModel {
  ScanResultModel({
    required this.acousticToken,
    required this.observedAt,
    this.bleNonce,
    this.rssi,
  });

  final String acousticToken;
  final DateTime observedAt;
  final String? bleNonce;
  final int? rssi;

  factory ScanResultModel.fromMap(Map<Object?, Object?> map) {
    final observed = map['observedAt']?.toString();
    return ScanResultModel(
      acousticToken: map['acousticToken']?.toString() ?? '',
      observedAt: observed == null
          ? DateTime.now().toUtc()
          : DateTime.parse(observed).toUtc(),
      bleNonce: map['bleNonce']?.toString(),
      rssi: map['rssi'] is int ? map['rssi'] as int : int.tryParse('${map['rssi']}'),
    );
  }
}
