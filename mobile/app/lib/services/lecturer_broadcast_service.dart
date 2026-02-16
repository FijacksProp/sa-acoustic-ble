import 'dart:async';
import 'dart:math';

import '../models/signal_payload_model.dart';

class BroadcastSnapshot {
  BroadcastSnapshot({
    required this.acousticPayload,
    required this.blePayload,
  });

  final AcousticPayload acousticPayload;
  final BlePayload blePayload;
}

class LecturerBroadcastService {
  static const int expirySeconds = 60;

  final _controller = StreamController<BroadcastSnapshot>.broadcast();
  Timer? _timer;
  BroadcastSnapshot? _latest;
  int? _sessionId;
  String _tokenVersion = 'v1';
  bool _running = false;

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
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: expirySeconds),
      (_) => _emitNewPayload(),
    );
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
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
    );
    _controller.add(_latest!);
  }

  String _randomToken({required String prefix}) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    final suffix = List.generate(12, (_) => chars[rand.nextInt(chars.length)]).join();
    return '${prefix}_$suffix';
  }
}
