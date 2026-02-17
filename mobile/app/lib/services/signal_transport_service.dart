import 'package:flutter/services.dart';

class SignalTransportService {
  static const MethodChannel _channel = MethodChannel('sa_acoustic_ble/acoustic');

  Future<void> startBroadcast({
    required String acousticToken,
    required String bleNonce,
  }) async {
    try {
      await _channel.invokeMethod<void>('startBroadcast', {
        'acousticToken': acousticToken,
        'bleNonce': bleNonce,
      });
    } on PlatformException {
      // No-op fallback for web/unsupported targets.
    } on MissingPluginException {
      // No-op fallback for web/unsupported targets.
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
}
