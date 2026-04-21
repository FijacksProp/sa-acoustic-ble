import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/scan_result_model.dart';
import '../models/signal_payload_model.dart';
import 'lecturer_broadcast_service.dart';
import 'signal_payload_codec.dart';

class BleScanService {
  static const String _serviceUuid = '0000aa91-0000-1000-8000-00805f9b34fb';
  static const int _manufacturerId = 0x0A91;

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
      final parsedHit = _findBestLecturerPayload(results);
      final advertisedName = strongest.advertisementData.advName.trim();
      final manufacturerData = strongest.advertisementData.manufacturerData;
      final serviceData = strongest.advertisementData.serviceData;
      final decodedPayload = parsedHit?.payload;
      final decodedNonce = parsedHit?.rawToken;
      final source = parsedHit?.source ?? 'ble_scan_unparsed_device';
      final diagnostic = parsedHit?.diagnostic ??
          'Scanned device ${strongest.device.remoteId.str} but no real lecturer nonce was parsed.';

      return ScanResultModel(
        acousticToken: '',
        observedAt: now,
        bleNonce: decodedNonce,
        rssi: strongest.rssi,
        sessionId: decodedPayload?.sessionId,
        issuedAt: decodedPayload?.issuedAt,
        source: source,
        diagnostic: decodedNonce != null
            ? diagnostic
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

  String? _decodeServicePayload(Map<Guid, List<int>> serviceData) {
    for (final entry in serviceData.entries) {
      if (entry.key.str128.toLowerCase() != _serviceUuid) {
        continue;
      }
      final decoded = String.fromCharCodes(entry.value).trim();
      if (decoded.isNotEmpty) {
        return decoded;
      }
    }
    return null;
  }

  _ParsedBleHit? _findBestLecturerPayload(List<ScanResult> results) {
    for (final result in results) {
      final manufacturerPayload = _decodeManufacturerPayload(
        result.advertisementData.manufacturerData,
      );
      if (manufacturerPayload != null) {
        final parsed = SignalPayloadCodec.parseBleNonce(manufacturerPayload);
        if (parsed != null) {
          return _ParsedBleHit(
            rawToken: manufacturerPayload,
            payload: parsed,
            source: 'ble_scan_manufacturer_data',
            diagnostic:
                'BLE payload parsed from manufacturer advertisement on ${result.device.remoteId.str}.',
          );
        }
      }

      final servicePayload = _decodeServicePayload(result.advertisementData.serviceData);
      if (servicePayload != null) {
        final parsed = SignalPayloadCodec.parseBleNonce(servicePayload);
        if (parsed != null) {
          return _ParsedBleHit(
            rawToken: servicePayload,
            payload: parsed,
            source: 'ble_scan_service_data',
            diagnostic:
                'BLE payload parsed from service data advertisement on ${result.device.remoteId.str}.',
          );
        }
      }

      final advName = result.advertisementData.advName.trim();
      if (advName.isNotEmpty) {
        final parsed = SignalPayloadCodec.parseBleNonce(advName);
        if (parsed != null) {
          return _ParsedBleHit(
            rawToken: advName,
            payload: parsed,
            source: 'ble_scan_token',
            diagnostic:
                'BLE payload parsed from advertisement name on ${result.device.remoteId.str}.',
          );
        }
      }
    }
    return null;
  }

  String? _decodeManufacturerPayload(Map<int, List<int>> manufacturerData) {
    final bytes = manufacturerData[_manufacturerId];
    if (bytes == null || bytes.length < 16) {
      return null;
    }
    final sessionId = _readInt32(bytes, 0);
    final issuedEpoch = _readInt32(bytes, 4);
    final nonce = String.fromCharCodes(bytes.sublist(8, 16)).replaceAll('_', '').trim();
    if (sessionId == null || issuedEpoch == null || nonce.isEmpty) {
      return null;
    }
    return 'ble|$sessionId|$issuedEpoch|$nonce';
  }

  int? _readInt32(List<int> bytes, int offset) {
    if (bytes.length < offset + 4) {
      return null;
    }
    return ((bytes[offset] & 0xff) << 24) |
        ((bytes[offset + 1] & 0xff) << 16) |
        ((bytes[offset + 2] & 0xff) << 8) |
        (bytes[offset + 3] & 0xff);
  }
}

class _ParsedBleHit {
  const _ParsedBleHit({
    required this.rawToken,
    required this.payload,
    required this.source,
    required this.diagnostic,
  });

  final String rawToken;
  final BlePayload payload;
  final String source;
  final String diagnostic;
}
