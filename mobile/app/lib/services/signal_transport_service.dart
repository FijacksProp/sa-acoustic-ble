import 'package:flutter/services.dart';

class BroadcastNativeStatus {
  const BroadcastNativeStatus({
    required this.acousticStatus,
    required this.bleStatus,
    required this.acousticPayloadPresent,
    required this.blePayloadPresent,
  });

  final String acousticStatus;
  final String bleStatus;
  final bool acousticPayloadPresent;
  final bool blePayloadPresent;

  factory BroadcastNativeStatus.fromMap(Map<String, dynamic>? map) {
    return BroadcastNativeStatus(
      acousticStatus: map?['acousticStatus']?.toString() ?? 'acoustic_status_unknown',
      bleStatus: map?['bleStatus']?.toString() ?? 'ble_status_unknown',
      acousticPayloadPresent: map?['acousticPayloadPresent'] == true,
      blePayloadPresent: map?['blePayloadPresent'] == true,
    );
  }
}

class SignalTransportService {
  static const MethodChannel _channel = MethodChannel('sa_acoustic_ble/acoustic');

  Future<BroadcastNativeStatus> startBroadcast({
    required String acousticToken,
    required String bleNonce,
  }) async {
    try {
      final response = await _channel.invokeMethod<Map<Object?, Object?>>('startBroadcast', {
        'acousticToken': acousticToken,
        'bleNonce': bleNonce,
      });
      return BroadcastNativeStatus.fromMap(
        response?.map((key, value) => MapEntry('$key', value)),
      );
    } on PlatformException catch (error) {
      return BroadcastNativeStatus(
        acousticStatus: 'native_platform_error',
        bleStatus: error.code,
        acousticPayloadPresent: acousticToken.trim().isNotEmpty,
        blePayloadPresent: bleNonce.trim().isNotEmpty,
      );
    } on MissingPluginException {
      return BroadcastNativeStatus(
        acousticStatus: 'native_plugin_unavailable',
        bleStatus: 'native_plugin_unavailable',
        acousticPayloadPresent: acousticToken.trim().isNotEmpty,
        blePayloadPresent: bleNonce.trim().isNotEmpty,
      );
    }
  }

  Future<void> stopBroadcast() async {
    try {
      await _channel.invokeMethod<void>('stopBroadcast');
    } on PlatformException {
      // No-op fallback for web/unsupported targets.
    } on MissingPluginException {
      // No-op fallback for web/unsupported targets.
    }
  }

  Future<Map<String, dynamic>?> getLatestBroadcast() async {
    try {
      final map = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getLatestBroadcast',
      );
      if (map == null) {
        return null;
      }
      return map.map((key, value) => MapEntry('$key', value));
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<Map<String, dynamic>?> ensureBleScanReady() async {
    try {
      final map = await _channel.invokeMethod<Map<Object?, Object?>>(
        'ensureBleScanReady',
      );
      if (map == null) {
        return null;
      }
      return map.map((key, value) => MapEntry('$key', value));
    } on PlatformException catch (error) {
      return {
        'ready': false,
        'status': error.code,
      };
    } on MissingPluginException {
      return {
        'ready': false,
        'status': 'native_plugin_unavailable',
      };
    }
  }

  Future<Map<String, dynamic>?> ensureStudentScanPermissions() async {
    try {
      final map = await _channel.invokeMethod<Map<Object?, Object?>>(
        'ensureStudentScanPermissions',
      );
      if (map == null) {
        return null;
      }
      return map.map((key, value) => MapEntry('$key', value));
    } on PlatformException catch (error) {
      return {
        'ready': false,
        'status': error.code,
      };
    } on MissingPluginException {
      return {
        'ready': false,
        'status': 'native_plugin_unavailable',
      };
    }
  }

  Future<Map<String, dynamic>?> ensureLecturerBroadcastPermissions() async {
    try {
      final map = await _channel.invokeMethod<Map<Object?, Object?>>(
        'ensureLecturerBroadcastPermissions',
      );
      if (map == null) {
        return null;
      }
      return map.map((key, value) => MapEntry('$key', value));
    } on PlatformException catch (error) {
      return {
        'ready': false,
        'status': error.code,
      };
    } on MissingPluginException {
      return {
        'ready': false,
        'status': 'native_plugin_unavailable',
      };
    }
  }
}
