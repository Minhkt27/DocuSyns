import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Connects to the local sidecar's status websocket (ws://127.0.0.1:8081/ws)
/// and forwards broadcast messages (e.g. "Uploading file: ...") to [onMessage].
/// Reconnects automatically with backoff if the sidecar isn't running yet or
/// the connection drops, since the sidecar is a separate local process that
/// may start after the app or restart independently.
///
/// Uses dart:io's WebSocket directly (rather than package:web_socket_channel)
/// because a refused connection there surfaces as an unhandled async
/// exception instead of a catchable error - this class only ever receives
/// messages, so the extra sink/channel abstraction isn't needed anyway.
class WebSocketService {
  WebSocket? _socket;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  bool _disposed = false;
  int _reconnectAttempt = 0;

  void Function(String)? _onMessage;

  void connect(void Function(String) onMessage) {
    _onMessage = onMessage;
    _disposed = false;
    _connectInternal();
  }

  Future<void> _connectInternal() async {
    if (_disposed) return;
    try {
      final socket = await WebSocket.connect('ws://127.0.0.1:8081/ws')
          .timeout(const Duration(seconds: 5));
      if (_disposed) {
        socket.close();
        return;
      }
      _socket = socket;
      _reconnectAttempt = 0;
      _subscription = socket.listen(
        (message) => _handleMessage(message.toString()),
        onError: (_) => _scheduleReconnect(),
        onDone: () => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _handleMessage(String raw) {
    String text = raw;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['message'] != null) {
        text = decoded['message'].toString();
      }
    } catch (_) {
      // Not JSON - forward the raw text as-is.
    }
    _onMessage?.call(text);
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _subscription?.cancel();
    _reconnectAttempt = (_reconnectAttempt + 1).clamp(1, 6);
    final delay = Duration(seconds: _reconnectAttempt * 2);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _connectInternal);
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _socket?.close();
  }
}
