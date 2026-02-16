import 'package:flutter/services.dart';

import '../models/scan_result_model.dart';
import '../models/signal_payload_model.dart';
import 'lecturer_broadcast_service.dart';
import 'signal_payload_codec.dart';

class AcousticScanService {
  static const MethodChannel _channel =
      MethodChannel('sa_acoustic_ble/acoustic');

  Future<ScanResultModel> startAcousticScan() async {
    final localBroadcast = LecturerBroadcastService.globalLatest;
    if (localBroadcast != null) {
      final decoded = SignalPayloadCodec.parseAcousticToken(localBroadcast.acousticToken);
      return ScanResultModel(
        acousticToken: localBroadcast.acousticToken,
        observedAt: DateTime.now().toUtc(),
        sessionId: decoded?.sessionId,
        tokenVersion: decoded?.tokenVersion,
        issuedAt: decoded?.issuedAt,
      );
    }

    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'startAcousticScan',
      );
      if (result == null) {
        return _fallback();
      }
      final base = ScanResultModel.fromMap(result);
      final decoded = SignalPayloadCodec.parseAcousticToken(base.acousticToken);
      if (decoded == null) {
        return _fallback();
      }
      return ScanResultModel(
        acousticToken: base.acousticToken,
        observedAt: base.observedAt,
        sessionId: decoded?.sessionId,
        tokenVersion: decoded?.tokenVersion,
        issuedAt: decoded?.issuedAt,
      );
    } on PlatformException {
      return _fallback();
    } on MissingPluginException {
      return _fallback();
    }
  }

  ScanResultModel _fallback() {
    final now = DateTime.now().toUtc();
    final mockPayload = SignalPayloadCodec.buildAcousticToken(
      AcousticPayload(
        sessionId: 1,
        tokenVersion: 'v1',
        challengeToken: 'fallback',
        issuedAt: now,
      ),
    );
    final decoded = SignalPayloadCodec.parseAcousticToken(mockPayload);
    return ScanResultModel(
      acousticToken: mockPayload,
      observedAt: now,
      sessionId: decoded?.sessionId,
      tokenVersion: decoded?.tokenVersion,
      issuedAt: decoded?.issuedAt,
    );
  }
}
