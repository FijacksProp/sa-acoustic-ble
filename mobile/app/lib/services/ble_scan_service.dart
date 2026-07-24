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
  static const String _eddystoneServiceUuid =
      '0000feaa-0000-1000-8000-00805f9b34fb';
  static const int _manufacturerId = 0x0A91;
  static const int _appleManufacturerId = 0x004C;
  static const int _rssiPreferenceMarginDb = 10;
  static const Duration _scanWindow = Duration(milliseconds: 2500);
  static const Duration _betweenWindows = Duration(milliseconds: 180);
  final _transport = SignalTransportService();

  Future<ScanResultModel> scanForNonce({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (kIsWeb) {
      final localBroadcast = LecturerBroadcastService.globalLatest;
      if (localBroadcast != null) {
        final decoded = SignalPayloadCodec.parseBleNonce(
          localBroadcast.bleNonce,
        );
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
        diagnostic:
            'Web mode has no real BLE scan path and no local broadcast cache.',
      );
    }

    try {
      final readiness = await _transport.ensureBleScanReady();
      if (readiness != null && readiness['ready'] != true) {
        if (readiness['status'] == 'bluetooth_off') {
          return ScanResultModel(
            acousticToken: '',
            observedAt: DateTime.now().toUtc(),
            source: 'ble_adapter_not_ready',
            diagnostic:
                'Bluetooth is off. Turn Bluetooth on for both lecturer and student phones.',
          );
        }
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
          diagnostic:
              'Bluetooth adapter is $adapterState. Turn Bluetooth on for both lecturer and student phones.',
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
      final lecturerHit = _findBestLecturerPayload(results);
      final beaconHit = _findBestRegisteredBeacon(results);

      if (lecturerHit != null || beaconHit != null) {
        return _buildPreferredBleResult(
          now: now,
          elapsedSeconds: DateTime.now().difference(startedAt).inSeconds,
          scanWindows: scanWindows,
          lecturerHit: lecturerHit,
          beaconHit: beaconHit,
          scanSummary: scanSummary,
        );
      }

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
      } catch (_) {}
      return ScanResultModel(
        acousticToken: '',
        observedAt: DateTime.now().toUtc(),
        source: 'ble_scan_error',
        diagnostic:
            'BLE scan failed before a lecturer nonce could be parsed: ${error.runtimeType}. ${error.toString()}',
      );
    }
  }

  ScanResultModel _buildPreferredBleResult({
    required DateTime now,
    required int elapsedSeconds,
    required int scanWindows,
    required _ParsedBleHit? lecturerHit,
    required _ParsedBeaconHit? beaconHit,
    required String scanSummary,
  }) {
    final selection = _selectBleEvidence(
      lecturerHit: lecturerHit,
      beaconHit: beaconHit,
    );
    final includeLecturer =
        lecturerHit != null &&
        (selection == _BleEvidenceSelection.lecturer ||
            selection == _BleEvidenceSelection.both);
    final includeBeacon =
        beaconHit != null &&
        (selection == _BleEvidenceSelection.beacon ||
            selection == _BleEvidenceSelection.both);
    final selectedRssi = _selectedRssi(
      lecturerHit: includeLecturer ? lecturerHit : null,
      beaconHit: includeBeacon ? beaconHit : null,
    );
    final source = switch (selection) {
      _BleEvidenceSelection.lecturer => lecturerHit?.source ?? 'ble_scan_token',
      _BleEvidenceSelection.beacon =>
        beaconHit?.source ?? 'ble_scan_beacon_eddystone_uid',
      _BleEvidenceSelection.both => 'ble_scan_lecturer_and_beacon',
    };
    final modeSummary = switch (selection) {
      _BleEvidenceSelection.lecturer =>
        'Selected lecturer BLE because it was clearly stronger.',
      _BleEvidenceSelection.beacon =>
        'Selected room beacon because it was clearly stronger.',
      _BleEvidenceSelection.both =>
        'Selected lecturer BLE + room beacon because RSSI values were within ${_rssiPreferenceMarginDb}dB.',
    };

    return ScanResultModel(
      acousticToken: '',
      observedAt: now,
      bleNonce: includeLecturer ? lecturerHit?.rawToken : null,
      rssi: selectedRssi,
      sessionId: includeLecturer ? lecturerHit?.payload.sessionId : null,
      issuedAt: includeLecturer ? lecturerHit?.payload.issuedAt : null,
      beaconProof: includeBeacon ? beaconHit?.proof : null,
      beaconType: includeBeacon ? beaconHit?.type : null,
      beaconUuid: includeBeacon ? beaconHit?.uuid : null,
      beaconMajor: includeBeacon ? beaconHit?.major : null,
      beaconMinor: includeBeacon ? beaconHit?.minor : null,
      beaconNamespaceId: includeBeacon ? beaconHit?.namespaceId : null,
      beaconInstanceId: includeBeacon ? beaconHit?.instanceId : null,
      source: source,
      diagnostic: [
        'BLE evidence collected after $scanWindows scan window(s), about ${elapsedSeconds}s.',
        modeSummary,
        if (lecturerHit != null)
          'Lecturer BLE RSSI ${lecturerHit.rssi}dBm. ${lecturerHit.diagnostic}',
        if (beaconHit != null)
          'Beacon RSSI ${beaconHit.rssi}dBm. ${beaconHit.diagnostic}',
        if (selectedRssi != null) _rssiQuality(selectedRssi),
        scanSummary,
      ].join(' '),
    );
  }

  _BleEvidenceSelection _selectBleEvidence({
    required _ParsedBleHit? lecturerHit,
    required _ParsedBeaconHit? beaconHit,
  }) {
    if (lecturerHit != null && beaconHit == null) {
      return _BleEvidenceSelection.lecturer;
    }
    if (lecturerHit == null && beaconHit != null) {
      return _BleEvidenceSelection.beacon;
    }
    if (lecturerHit == null || beaconHit == null) {
      return _BleEvidenceSelection.beacon;
    }

    final difference = lecturerHit.rssi - beaconHit.rssi;
    if (difference >= _rssiPreferenceMarginDb) {
      return _BleEvidenceSelection.lecturer;
    }
    if (difference <= -_rssiPreferenceMarginDb) {
      return _BleEvidenceSelection.beacon;
    }
    return _BleEvidenceSelection.both;
  }

  int? _selectedRssi({
    required _ParsedBleHit? lecturerHit,
    required _ParsedBeaconHit? beaconHit,
  }) {
    if (lecturerHit != null && beaconHit != null) {
      return lecturerHit.rssi >= beaconHit.rssi
          ? lecturerHit.rssi
          : beaconHit.rssi;
    }
    return lecturerHit?.rssi ?? beaconHit?.rssi;
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

      final servicePayload = _decodeServicePayload(
        result.advertisementData.serviceData,
      );
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

  _ParsedBeaconHit? _findBestRegisteredBeacon(List<ScanResult> results) {
    for (final result in results) {
      final iBeacon = _parseIBeacon(
        result.advertisementData.manufacturerData[_appleManufacturerId],
      );
      if (iBeacon != null) {
        return _ParsedBeaconHit(
          proof:
              'beacon|ibeacon|${iBeacon.uuid}|${iBeacon.major}|${iBeacon.minor}',
          type: 'ibeacon',
          uuid: iBeacon.uuid,
          major: iBeacon.major,
          minor: iBeacon.minor,
          namespaceId: null,
          instanceId: null,
          rssi: result.rssi,
          source: 'ble_scan_beacon_ibeacon',
          diagnostic:
              'iBeacon UUID ${iBeacon.uuid}, major ${iBeacon.major}, minor ${iBeacon.minor}.',
        );
      }

      final eddystone = _parseEddystoneUid(
        result.advertisementData.serviceData,
      );
      if (eddystone != null) {
        final proof = SignalPayloadCodec.buildEddystoneBeaconProof(
          namespaceId: eddystone.namespaceId,
          instanceId: eddystone.instanceId,
        );
        return _ParsedBeaconHit(
          proof: proof,
          type: 'eddystone_uid',
          uuid: null,
          major: null,
          minor: null,
          namespaceId: eddystone.namespaceId,
          instanceId: eddystone.instanceId,
          rssi: result.rssi,
          source: 'ble_scan_beacon_eddystone_uid',
          diagnostic:
              'Eddystone UID namespace ${eddystone.namespaceId}, instance ${eddystone.instanceId}.',
        );
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
    final nonce = String.fromCharCodes(
      bytes.sublist(8, 16),
    ).replaceAll('_', '').trim();
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

  _IBeaconFrame? _parseIBeacon(List<int>? bytes) {
    if (bytes == null || bytes.length < 23) {
      return null;
    }
    int? offset;
    for (var i = 0; i <= bytes.length - 23; i += 1) {
      if (bytes[i] == 0x02 && bytes[i + 1] == 0x15) {
        offset = i;
        break;
      }
    }
    if (offset == null) {
      return null;
    }
    final uuidBytes = bytes.sublist(offset + 2, offset + 18);
    final major = _readUInt16(bytes, offset + 18);
    final minor = _readUInt16(bytes, offset + 20);
    final txPowerByte = bytes[offset + 22];
    final txPower = txPowerByte > 127 ? txPowerByte - 256 : txPowerByte;
    if (major == null || minor == null) {
      return null;
    }
    return _IBeaconFrame(
      uuid: _formatUuid(uuidBytes),
      major: major,
      minor: minor,
      txPower: txPower,
    );
  }

  _EddystoneUidFrame? _parseEddystoneUid(Map<Guid, List<int>> serviceData) {
    for (final entry in serviceData.entries) {
      if (entry.key.str128.toLowerCase() != _eddystoneServiceUuid) {
        continue;
      }
      final bytes = entry.value;
      if (bytes.length < 18 || bytes[0] != 0x00) {
        continue;
      }
      final txPowerByte = bytes[1];
      final txPower = txPowerByte > 127 ? txPowerByte - 256 : txPowerByte;
      return _EddystoneUidFrame(
        namespaceId: _bytesToCompactHex(bytes.sublist(2, 12)),
        instanceId: _bytesToCompactHex(bytes.sublist(12, 18)),
        txPower: txPower,
      );
    }
    return null;
  }

  String _bytesToCompactHex(List<int> bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  String _formatUuid(List<int> bytes) {
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    if (hex.length != 32) {
      return hex;
    }
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }

  int? _readUInt16(List<int> bytes, int offset) {
    if (bytes.length < offset + 2) {
      return null;
    }
    return ((bytes[offset] & 0xff) << 8) | (bytes[offset + 1] & 0xff);
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

class _ParsedBeaconHit {
  const _ParsedBeaconHit({
    required this.proof,
    required this.type,
    required this.uuid,
    required this.major,
    required this.minor,
    required this.namespaceId,
    required this.instanceId,
    required this.rssi,
    required this.source,
    required this.diagnostic,
  });

  final String proof;
  final String type;
  final String? uuid;
  final int? major;
  final int? minor;
  final String? namespaceId;
  final String? instanceId;
  final int rssi;
  final String source;
  final String diagnostic;
}

enum _BleEvidenceSelection { lecturer, beacon, both }

class _IBeaconFrame {
  const _IBeaconFrame({
    required this.uuid,
    required this.major,
    required this.minor,
    required this.txPower,
  });

  final String uuid;
  final int major;
  final int minor;
  final int txPower;
}

class _EddystoneUidFrame {
  const _EddystoneUidFrame({
    required this.namespaceId,
    required this.instanceId,
    required this.txPower,
  });

  final String namespaceId;
  final String instanceId;
  final int txPower;
}
