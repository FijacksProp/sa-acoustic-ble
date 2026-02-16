class AcousticPayload {
  AcousticPayload({
    required this.sessionId,
    required this.tokenVersion,
    required this.challengeToken,
    required this.issuedAt,
  });

  final int sessionId;
  final String tokenVersion;
  final String challengeToken;
  final DateTime issuedAt;

  bool isExpired({int expirySeconds = 60}) {
    return DateTime.now().toUtc().difference(issuedAt).inSeconds > expirySeconds;
  }
}

class BlePayload {
  BlePayload({
    required this.sessionId,
    required this.bleNonce,
    required this.issuedAt,
  });

  final int sessionId;
  final String bleNonce;
  final DateTime issuedAt;

  bool isExpired({int expirySeconds = 60}) {
    return DateTime.now().toUtc().difference(issuedAt).inSeconds > expirySeconds;
  }
}
