import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/scan_result_model.dart';
import 'lecturer_broadcast_service.dart';
import 'signal_payload_codec.dart';

class AcousticScanService {
  static const MethodChannel _channel =
      MethodChannel('sa_acoustic_ble/acoustic');

  Future<ScanResultModel> startAcousticScan() async {
    if (kIsWeb) {
      final localBroadcast = LecturerBroadcastService.globalLatest;
      if (localBroadcast != null) {
        final decoded = SignalPayloadCodec.parseAcousticToken(localBroadcast.acousticToken);
        return ScanResultModel(
          acousticToken: localBroadcast.acousticToken,
          observedAt: DateTime.now().toUtc(),
          sessionId: decoded?.sessionId,
          tokenVersion: decoded?.tokenVersion,
          issuedAt: decoded?.issuedAt,
          source: 'web_broadcast_cache',
          diagnostic: 'Using in-memory lecturer broadcast for web/demo mode.',
        );
      }
      return ScanResultModel(
        acousticToken: '',
        observedAt: DateTime.now().toUtc(),
        source: 'web_no_broadcast',
        diagnostic: 'No in-memory lecturer broadcast is available in web mode.',
      );
    }

    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'startAcousticScan',
      );
      if (result == null) {
        return ScanResultModel(
          acousticToken: '',
          observedAt: DateTime.now().toUtc(),
          source: 'native_no_result',
          diagnostic: 'Native acoustic scan returned no result.',
        );
      }
      final base = ScanResultModel.fromMap(result);
      final decoded = SignalPayloadCodec.parseAcousticToken(base.acousticToken);
      return ScanResultModel(
        acousticToken: base.acousticToken,
        observedAt: base.observedAt,
        sessionId: decoded?.sessionId ?? base.sessionId,
        tokenVersion: decoded?.tokenVersion ?? base.tokenVersion,
        issuedAt: decoded?.issuedAt ?? base.issuedAt,
        source: base.source ?? (decoded != null ? 'native_decode' : 'native_no_decode'),
        diagnostic: base.diagnostic,
      );
    } on PlatformException {
      return ScanResultModel(
        acousticToken: '',
        observedAt: DateTime.now().toUtc(),
        source: 'platform_exception',
        diagnostic: 'Native acoustic platform call failed.',
      );
    } on MissingPluginException {
      return ScanResultModel(
        acousticToken: '',
        observedAt: DateTime.now().toUtc(),
        source: 'missing_plugin',
        diagnostic: 'Acoustic native plugin is unavailable on this target.',
      );
    }
  }
}
