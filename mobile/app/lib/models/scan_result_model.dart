class ScanResultModel {
  ScanResultModel({
    required this.acousticToken,
    required this.observedAt,
    this.bleNonce,
    this.rssi,
    this.sessionId,
    this.tokenVersion,
    this.issuedAt,
    this.beaconProof,
    this.beaconType,
    this.beaconUuid,
    this.beaconMajor,
    this.beaconMinor,
    this.beaconNamespaceId,
    this.beaconInstanceId,
    this.source,
    this.diagnostic,
  });

  final String acousticToken;
  final DateTime observedAt;
  final String? bleNonce;
  final int? rssi;
  final int? sessionId;
  final String? tokenVersion;
  final DateTime? issuedAt;
  final String? beaconProof;
  final String? beaconType;
  final String? beaconUuid;
  final int? beaconMajor;
  final int? beaconMinor;
  final String? beaconNamespaceId;
  final String? beaconInstanceId;
  final String? source;
  final String? diagnostic;

  factory ScanResultModel.fromMap(Map<Object?, Object?> map) {
    final observed = map['observedAt']?.toString();
    return ScanResultModel(
      acousticToken: map['acousticToken']?.toString() ?? '',
      observedAt: observed == null
          ? DateTime.now().toUtc()
          : DateTime.parse(observed).toUtc(),
      bleNonce: map['bleNonce']?.toString(),
      rssi: map['rssi'] is int
          ? map['rssi'] as int
          : int.tryParse('${map['rssi']}'),
      sessionId: map['sessionId'] is int
          ? map['sessionId'] as int
          : int.tryParse('${map['sessionId']}'),
      tokenVersion: map['tokenVersion']?.toString(),
      issuedAt: map['issuedAt'] == null
          ? null
          : DateTime.tryParse(map['issuedAt'].toString())?.toUtc(),
      beaconProof: map['beaconProof']?.toString(),
      beaconType: map['beaconType']?.toString(),
      beaconUuid: map['beaconUuid']?.toString(),
      beaconMajor: map['beaconMajor'] is int
          ? map['beaconMajor'] as int
          : int.tryParse('${map['beaconMajor']}'),
      beaconMinor: map['beaconMinor'] is int
          ? map['beaconMinor'] as int
          : int.tryParse('${map['beaconMinor']}'),
      beaconNamespaceId: map['beaconNamespaceId']?.toString(),
      beaconInstanceId: map['beaconInstanceId']?.toString(),
      source: map['source']?.toString(),
      diagnostic: map['diagnostic']?.toString(),
    );
  }
}
