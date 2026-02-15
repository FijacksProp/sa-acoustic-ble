import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/scan_result_model.dart';

class BleScanService {
  Future<ScanResultModel> scanForNonce({
    Duration timeout = const Duration(seconds: 5),
  }) async {
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

      return ScanResultModel(
        acousticToken: '',
        observedAt: DateTime.now().toUtc(),
        bleNonce: 'ble_$deviceId',
        rssi: strongest.rssi,
      );
    } catch (_) {
      return _fallback();
    }
  }

  ScanResultModel _fallback() {
    final now = DateTime.now().toUtc();
    return ScanResultModel(
      acousticToken: '',
      observedAt: now,
      bleNonce: 'mock_ble_${now.millisecondsSinceEpoch}',
      rssi: -60,
    );
  }
}
