import 'package:flutter/services.dart';

import '../models/scan_result_model.dart';

class AcousticScanService {
  static const MethodChannel _channel =
      MethodChannel('sa_acoustic_ble/acoustic');

  Future<ScanResultModel> startAcousticScan() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'startAcousticScan',
      );
      if (result == null) {
        return _fallback();
      }
      return ScanResultModel.fromMap(result);
    } on PlatformException {
      return _fallback();
    } on MissingPluginException {
      return _fallback();
    }
  }

  ScanResultModel _fallback() {
    final now = DateTime.now().toUtc();
    return ScanResultModel(
      acousticToken: 'mock_ac_${now.millisecondsSinceEpoch}',
      observedAt: now,
    );
  }
}
