import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket 클라이언트 — 실시간 도장 적립 이벤트 수신
class WSClient {
  // 빌드 시 --dart-define=WS_BASE=ws://<서버주소>:8080 로 주입
  static const String _baseUrl = String.fromEnvironment(
    'WS_BASE',
    defaultValue: 'ws://10.0.2.2:8080', // Android emulator 기본값
  );

  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  String? _guestId;
  bool _isConnected = false;

  /// 이벤트 콜백
  Function(Map<String, dynamic>)? onStampEarned;
  Function(Map<String, dynamic>)? onCouponEarned;
  Function()? onConnected;
  Function()? onDisconnected;

  /// WebSocket 연결
  void connect(String guestId) {
    _guestId = guestId;
    _doConnect();
  }

  void _doConnect() {
    if (_guestId == null) return;

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('$_baseUrl/ws/$_guestId'),
      );

      _channel!.stream.listen(
        (message) => _onMessage(message),
        onError: (error) {
          _isConnected = false;
          onDisconnected?.call();
          _scheduleReconnect();
        },
        onDone: () {
          _isConnected = false;
          onDisconnected?.call();
          _scheduleReconnect();
        },
      );

      _isConnected = true;
      onConnected?.call();
      _startHeartbeat();
    } catch (e) {
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic message) {
    try {
      if (message == 'pong') return; // heartbeat response

      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final event = data['event'] as String?;

      switch (event) {
        case 'stamp_earned':
          onStampEarned?.call(data);
          break;
        case 'coupon_earned':
          onCouponEarned?.call(data);
          break;
      }
    } catch (e) {
      // Ignore parse errors
    }
  }

  /// Heartbeat (30초 간격)
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (_isConnected) {
          _channel?.sink.add('ping');
        }
      },
    );
  }

  /// 자동 재연결 (3초 후)
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      _doConnect();
    });
  }

  /// 연결 해제
  void disconnect() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _isConnected = false;
  }

  bool get isConnected => _isConnected;
}
