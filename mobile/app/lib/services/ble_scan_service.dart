import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/scan_result_model.dart';
import '../models/signal_payload_model.dart';
import 'lecturer_broadcast_service.dart';
import 'signal_payload_codec.dart';
import 'signal_transport_service.dart';

class BleScanService {
  static const String _serviceUuid = '0000aa91-0000-1000-8000-00805f9b34fb';
  static const int _manufacturerId = 0x0A91;
  static const Duration _scanWindow = Duration(milliseconds: 2500);
  static const Duration _betweenWindows = Duration(milliseconds: 180);
  final _transport = SignalTransportService();

  Future<ScanResultModel> scanForNonce({
    Duration timeout = const Duration(seconds: 10),
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
      final readiness = await _transport.ensureBleScanReady();
      if (readiness != null && readiness['ready'] != true) {
        return ScanResultModel(
          acousticToken: '',
          observedAt: DateTime.now().toUtc(),
          source: 'ble_scan_not_ready',
          diagnostic:
              'BLE scan is not ready: ${readiness['status']}. If a permission prompt appeared, allow it and scan again.',
        );
      }

      final adapterState = await FlutterBluePlus.adapterState.first.timeout(
        const Duration(seconds: 2),
        onTimeout: () => BluetoothAdapterState.unknown,
      );
      if (adapterState != BluetoothAdapterState.on) {
        return ScanResultModel(
          acousticToken: '',
          observedAt: DateTime.now().toUtc(),
          source: 'ble_adapter_not_ready',
          diagnostic: 'Bluetooth adapter is $adapterState. Turn Bluetooth on for both lecturer and student phones.',
        );
      }

      final seen = <String, ScanResult>{};
      var scanWindows = 0;
      final startedAt = DateTime.now();
      final deadline = startedAt.add(timeout);

      while (DateTime.now().isBefore(deadline)) {
        scanWindows += 1;
        final remaining = deadline.difference(DateTime.now());
        final window = remaining < _scanWindow ? remaining : _scanWindow;
        if (window.inMilliseconds <= 0) {
          break;
        }

        await FlutterBluePlus.stopScan();
        await FlutterBluePlus.startScan(timeout: window);
        await Future.delayed(window + const Duration(milliseconds: 120));
        _mergeResults(seen, FlutterBluePlus.lastScanResults);
        await FlutterBluePlus.stopScan();

        final collected = seen.values.toList()
          ..sort((a, b) => b.rssi.compareTo(a.rssi));
        final parsedHit = _findBestLecturerPayload(collected);
        if (parsedHit != null) {
          final now = DateTime.now().toUtc();
          final elapsed = DateTime.now().difference(startedAt).inSeconds;
          return ScanResultModel(
            acousticToken: '',
            observedAt: now,
            bleNonce: parsedHit.rawToken,
            rssi: parsedHit.rssi,
            sessionId: parsedHit.payload.sessionId,
            issuedAt: parsedHit.payload.issuedAt,
            source: parsedHit.source,
            diagnostic:
                'BLE lecturer broadcast found after ${scanWindows} scan window(s), about ${elapsed}s. ${_rssiQuality(parsedHit.rssi)} ${parsedHit.diagnostic}',
          );
        }

        if (DateTime.now().isBefore(deadline)) {
          await Future.delayed(_betweenWindows);
        }
      }

      final results = seen.values.toList()
        ..sort((a, b) => b.rssi.compareTo(a.rssi));

      if (results.isEmpty) {
        return ScanResultModel(
          acousticToken: '',
          observedAt: DateTime.now().toUtc(),
          source: 'ble_scan_empty',
          diagnostic:
              'BLE room scan completed but no nearby devices were returned. Check Bluetooth is on, permissions are granted, and lecturer BLE advertising actually started.',
        );
      }

      final strongest = results.first;
      final now = DateTime.now().toUtc();
      final advertisedName = strongest.advertisementData.advName.trim();
      final manufacturerData = strongest.advertisementData.manufacturerData;
      final serviceData = strongest.advertisementData.serviceData;
      final scanSummary = _scanSummary(results);

      return ScanResultModel(
        acousticToken: '',
        observedAt: now,
        bleNonce: null,
        rssi: strongest.rssi,
        source: 'ble_scan_unparsed_device',
        diagnostic:
            'Scanned strongest device ${strongest.device.remoteId.str} (name: ${advertisedName.isEmpty ? '-' : advertisedName}, manufacturerData: ${manufacturerData.length}, serviceData: ${serviceData.length}). ${_rssiQuality(strongest.rssi)} $scanSummary',
      );
    } catch (error) {
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {
      }
      return ScanResultModel(
        acousticToken: '',
        observedAt: DateTime.now().toUtc(),
        source: 'ble_scan_error',
        diagnostic:
            'BLE scan failed before a lecturer nonce could be parsed: ${error.runtimeType}. ${error.toString()}',
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
            rssi: result.rssi,
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
            rssi: result.rssi,
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
            rssi: result.rssi,
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

  String _scanSummary(List<ScanResult> results) {
    final manufacturerIds = <int>{};
    var manufacturerAdvertisementCount = 0;
    var serviceAdvertisementCount = 0;
    var namedDeviceCount = 0;
    var strongestRssi = -999;
    for (final result in results) {
      if (result.rssi > strongestRssi) {
        strongestRssi = result.rssi;
      }
      if (result.advertisementData.advName.trim().isNotEmpty) {
        namedDeviceCount += 1;
      }
      if (result.advertisementData.manufacturerData.isNotEmpty) {
        manufacturerAdvertisementCount += 1;
        manufacturerIds.addAll(result.advertisementData.manufacturerData.keys);
      }
      if (result.advertisementData.serviceData.isNotEmpty) {
        serviceAdvertisementCount += 1;
      }
    }
    final ids = manufacturerIds.isEmpty
        ? '-'
        : manufacturerIds.map((id) => '0x${id.toRadixString(16)}').join(',');
    return 'Seen=${results.length}, named=$namedDeviceCount, manufacturerAds=$manufacturerAdvertisementCount, serviceAds=$serviceAdvertisementCount, strongestRssi=$strongestRssi, manufacturerIds=$ids, expectedManufacturerId=0xa91.';
  }

  void _mergeResults(Map<String, ScanResult> seen, List<ScanResult> results) {
    for (final result in results) {
      final key = result.device.remoteId.str;
      final existing = seen[key];
      if (existing == null || result.rssi > existing.rssi) {
        seen[key] = result;
      }
    }
  }

  String _rssiQuality(int rssi) {
    if (rssi >= -65) {
      return 'Signal quality: strong.';
    }
    if (rssi >= -75) {
      return 'Signal quality: usable.';
    }
    if (rssi >= -85) {
      return 'Signal quality: weak; distance or obstruction may affect it.';
    }
    return 'Signal quality: very weak; move closer or improve lecturer phone placement.';
  }
}

class _ParsedBleHit {
  const _ParsedBleHit({
    required this.rawToken,
    required this.payload,
    required this.rssi,
    required this.source,
    required this.diagnostic,
  });

  final String rawToken;
  final BlePayload payload;
  final int rssi;
  final String source;
  final String diagnostic;
}
