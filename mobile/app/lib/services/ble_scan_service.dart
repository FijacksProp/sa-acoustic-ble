import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/scan_result_model.dart';
import '../models/signal_payload_model.dart';
import 'lecturer_broadcast_service.dart';
import 'signal_payload_codec.dart';

class BleScanService {
  Future<ScanResultModel> scanForNonce({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final localBroadcast = LecturerBroadcastService.globalLatest;
    if (localBroadcast != null) {
      final decoded = SignalPayloadCodec.parseBleNonce(localBroadcast.bleNonce);
      return ScanResultModel(
        acousticToken: '',
        observedAt: DateTime.now().toUtc(),
        bleNonce: localBroadcast.bleNonce,
        rssi: -45,
        sessionId: decoded?.sessionId,
        issuedAt: decoded?.issuedAt,
      );
    }

    if (kIsWeb) {
      return _fallback();
    }

    try {
      await FlutterBluePlus.stopScan();
      await FlutterBluePlus.startScan(timeout: timeout);
      await Future.delayed(timeout);
      final results = FlutterBluePlus.lastScanResults;
      await FlutterBluePlus.stopScan();

      if (results.isEmpty) {
        return _fallback();
      }

      results.sort((a, b) => b.rssi.compareTo(a.rssi));
      final strongest = results.first;
      final deviceId = strongest.device.remoteId.str;
      final now = DateTime.now().toUtc();
      final encoded = SignalPayloadCodec.buildBleNonce(
        BlePayload(
          sessionId: 1,
          bleNonce: 'dev_$deviceId',
          issuedAt: now,
        ),
      );
      final decoded = SignalPayloadCodec.parseBleNonce(encoded);

      return ScanResultModel(
        acousticToken: '',
        observedAt: now,
        bleNonce: encoded,
        rssi: strongest.rssi,
        sessionId: decoded?.sessionId,
        issuedAt: decoded?.issuedAt,
      );
    } catch (_) {
      return _fallback();
    }
  }

  ScanResultModel _fallback() {
    final now = DateTime.now().toUtc();
    final encoded = SignalPayloadCodec.buildBleNonce(
      BlePayload(
        sessionId: 1,
        bleNonce: 'fallback',
        issuedAt: now,
      ),
    );
    final decoded = SignalPayloadCodec.parseBleNonce(encoded);
    return ScanResultModel(
      acousticToken: '',
      observedAt: now,
      bleNonce: encoded,
      rssi: -60,
      sessionId: decoded?.sessionId,
      issuedAt: decoded?.issuedAt,
    );
  }
}
