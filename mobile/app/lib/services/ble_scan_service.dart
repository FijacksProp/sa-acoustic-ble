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
    if (kIsWeb) {
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
          source: 'web_broadcast_cache',
          diagnostic: 'Using in-memory lecturer BLE payload for web/demo mode.',
        );
      }
      return ScanResultModel(
        acousticToken: '',
        observedAt: DateTime.now().toUtc(),
        source: 'web_no_ble',
        diagnostic: 'Web mode has no real BLE scan path and no local broadcast cache.',
      );
    }

    try {
      await FlutterBluePlus.stopScan();
      await FlutterBluePlus.startScan(timeout: timeout);
      await Future.delayed(timeout);
      final results = FlutterBluePlus.lastScanResults;
      await FlutterBluePlus.stopScan();

      if (results.isEmpty) {
        return ScanResultModel(
          acousticToken: '',
          observedAt: DateTime.now().toUtc(),
          source: 'ble_scan_empty',
          diagnostic: 'BLE scan completed but no nearby devices were returned.',
        );
      }

      results.sort((a, b) => b.rssi.compareTo(a.rssi));
      final strongest = results.first;
      final now = DateTime.now().toUtc();
      final advertisedName = strongest.advertisementData.advName.trim();
      final manufacturerData = strongest.advertisementData.manufacturerData;
      final serviceData = strongest.advertisementData.serviceData;
      BlePayload? decodedPayload;
      String? decodedNonce;

      if (advertisedName.isNotEmpty) {
        final parsed = SignalPayloadCodec.parseBleNonce(advertisedName);
        if (parsed != null) {
          decodedNonce = advertisedName;
          decodedPayload = parsed;
        }
      }

      return ScanResultModel(
        acousticToken: '',
        observedAt: now,
        bleNonce: decodedNonce,
        rssi: strongest.rssi,
        sessionId: decodedPayload?.sessionId,
        issuedAt: decodedPayload?.issuedAt,
        source: decodedNonce != null ? 'ble_scan_token' : 'ble_scan_unparsed_device',
        diagnostic: decodedNonce != null
            ? 'BLE payload parsed from advertisement name.'
            : 'Scanned device ${strongest.device.remoteId.str} (name: ${advertisedName.isEmpty ? '-' : advertisedName}, manufacturerData: ${manufacturerData.length}, serviceData: ${serviceData.length}) but no real lecturer nonce was parsed.',
      );
    } catch (_) {
      return ScanResultModel(
        acousticToken: '',
        observedAt: DateTime.now().toUtc(),
        source: 'ble_scan_error',
        diagnostic: 'BLE scan failed before a lecturer nonce could be parsed.',
      );
    }
  }
}
