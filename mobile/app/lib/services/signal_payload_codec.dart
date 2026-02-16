import '../models/signal_payload_model.dart';

class SignalPayloadCodec {
  static const int expirySeconds = 60;

  static String buildAcousticToken(AcousticPayload payload) {
    final issuedEpoch = payload.issuedAt.toUtc().millisecondsSinceEpoch ~/ 1000;
    return [
      'ac',
      payload.sessionId.toString(),
      payload.tokenVersion,
      issuedEpoch.toString(),
      payload.challengeToken,
    ].join('|');
  }

  static String buildBleNonce(BlePayload payload) {
    final issuedEpoch = payload.issuedAt.toUtc().millisecondsSinceEpoch ~/ 1000;
    return [
      'ble',
      payload.sessionId.toString(),
      issuedEpoch.toString(),
      payload.bleNonce,
    ].join('|');
  }

  static AcousticPayload? parseAcousticToken(String raw) {
    final parts = raw.split('|');
    if (parts.length != 5 || parts[0] != 'ac') {
      return null;
    }
    final sessionId = int.tryParse(parts[1]);
    final issuedEpoch = int.tryParse(parts[3]);
    if (sessionId == null || issuedEpoch == null) {
      return null;
    }
    return AcousticPayload(
      sessionId: sessionId,
      tokenVersion: parts[2],
      challengeToken: parts[4],
      issuedAt: DateTime.fromMillisecondsSinceEpoch(
        issuedEpoch * 1000,
        isUtc: true,
      ),
    );
  }

  static BlePayload? parseBleNonce(String raw) {
    final parts = raw.split('|');
    if (parts.length != 4 || parts[0] != 'ble') {
      return null;
    }
    final sessionId = int.tryParse(parts[1]);
    final issuedEpoch = int.tryParse(parts[2]);
    if (sessionId == null || issuedEpoch == null) {
      return null;
    }
    return BlePayload(
      sessionId: sessionId,
      bleNonce: parts[3],
      issuedAt: DateTime.fromMillisecondsSinceEpoch(
        issuedEpoch * 1000,
        isUtc: true,
      ),
    );
  }

  static int signalAgeSeconds(DateTime issuedAtUtc) {
    return DateTime.now().toUtc().difference(issuedAtUtc).inSeconds;
  }

  static bool isFresh(DateTime issuedAtUtc) {
    final age = signalAgeSeconds(issuedAtUtc);
    return age >= 0 && age <= expirySeconds;
  }
}
