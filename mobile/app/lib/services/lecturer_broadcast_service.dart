import 'dart:async';
import 'dart:math';

import '../models/signal_payload_model.dart';
import 'signal_payload_codec.dart';
import 'signal_transport_service.dart';

class BroadcastSnapshot {
  BroadcastSnapshot({
    required this.acousticPayload,
    required this.blePayload,
    required this.acousticToken,
    required this.bleNonce,
  });

  final AcousticPayload acousticPayload;
  final BlePayload blePayload;
  final String acousticToken;
  final String bleNonce;
}

class LecturerBroadcastService {
  static const int expirySeconds = 60;
  static BroadcastSnapshot? globalLatest;

  final _controller = StreamController<BroadcastSnapshot>.broadcast();
  Timer? _timer;
  BroadcastSnapshot? _latest;
  int? _sessionId;
  String _tokenVersion = 'v1';
  bool _running = false;
  final _transport = SignalTransportService();

  Stream<BroadcastSnapshot> get stream => _controller.stream;
  BroadcastSnapshot? get latest => _latest;
  bool get isRunning => _running;

  void start({
    required int sessionId,
    required String tokenVersion,
  }) {
    _sessionId = sessionId;
    _tokenVersion = tokenVersion.trim().isEmpty ? 'v1' : tokenVersion.trim();
    _running = true;
    _emitNewPayload();
    _startNativeBroadcast();
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: expirySeconds),
      (_) {
        _emitNewPayload();
        _startNativeBroadcast();
      },
    );
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
    _transport.stopBroadcast();
  }

  void dispose() {
    stop();
    _controller.close();
  }

  void _emitNewPayload() {
    if (_sessionId == null) {
      return;
    }
    final issuedAt = DateTime.now().toUtc();
    final challengeToken = _randomToken(prefix: 'ac');
    final bleNonce = _randomToken(prefix: 'ble');

    _latest = BroadcastSnapshot(
      acousticPayload: AcousticPayload(
        sessionId: _sessionId!,
        tokenVersion: _tokenVersion,
        challengeToken: challengeToken,
        issuedAt: issuedAt,
      ),
      blePayload: BlePayload(
        sessionId: _sessionId!,
        bleNonce: bleNonce,
        issuedAt: issuedAt,
      ),
      acousticToken: SignalPayloadCodec.buildAcousticToken(
        AcousticPayload(
          sessionId: _sessionId!,
          tokenVersion: _tokenVersion,
          challengeToken: challengeToken,
          issuedAt: issuedAt,
        ),
      ),
      bleNonce: SignalPayloadCodec.buildBleNonce(
        BlePayload(
          sessionId: _sessionId!,
          bleNonce: bleNonce,
          issuedAt: issuedAt,
        ),
      ),
    );
    globalLatest = _latest;
    _controller.add(_latest!);
  }

  void _startNativeBroadcast() {
    final snapshot = _latest;
    if (snapshot == null) {
      return;
    }
    _transport.startBroadcast(
      acousticToken: snapshot.acousticToken,
      bleNonce: snapshot.bleNonce,
    );
  }

  String _randomToken({required String prefix}) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    final suffix = List.generate(12, (_) => chars[rand.nextInt(chars.length)]).join();
    return '${prefix}_$suffix';
  }
}
