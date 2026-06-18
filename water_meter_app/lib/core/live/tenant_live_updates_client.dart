import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'live_update_message.dart';

typedef LiveUpdatesMessageHandler = void Function(LiveUpdateMessage message);
typedef LiveConnectionStateHandler = void Function({
  required bool connected,
  required bool reconnecting,
});

class TenantLiveUpdatesClient {
  TenantLiveUpdatesClient({
    required this.wsUrl,
    required this.tenantId,
    required this.tokenProvider,
    this.onMessage,
    this.onConnectionStateChanged,
    this.baseReconnectDelay = const Duration(seconds: 2),
    this.maxReconnectDelay = const Duration(seconds: 60),
    WebSocketChannel Function(Uri uri)? channelFactory,
  }) : _channelFactory = channelFactory ?? ((uri) => WebSocketChannel.connect(uri));

  final String wsUrl;
  final String tenantId;
  final Future<String?> Function() tokenProvider;
  final LiveUpdatesMessageHandler? onMessage;
  final LiveConnectionStateHandler? onConnectionStateChanged;
  final Duration baseReconnectDelay;
  final Duration maxReconnectDelay;
  final WebSocketChannel Function(Uri uri) _channelFactory;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  bool _stopped = false;
  int _reconnectAttempt = 0;
  bool _connected = false;

  bool get isConnected => _connected;

  void sendJson(Map<String, dynamic> payload) {
    if (!_connected || _channel == null) return;
    _channel!.sink.add(jsonEncode(payload));
  }

  Future<void> connect() async {
    _stopped = false;
    await _openChannel();
  }

  Future<void> reconnectNow() async {
    _reconnectAttempt = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _openChannel();
  }

  Future<void> disconnect() async {
    _stopped = true;
    _reconnectAttempt = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    _connected = false;
    onConnectionStateChanged?.call(connected: false, reconnecting: false);
  }

  Future<void> _openChannel() async {
    if (_stopped) return;

    onConnectionStateChanged?.call(
      connected: false,
      reconnecting: _reconnectAttempt > 0,
    );

    final token = await tokenProvider();
    if (token == null || token.isEmpty) {
      _scheduleReconnect();
      return;
    }

    await _subscription?.cancel();
    await _channel?.sink.close();

    try {
      final channel = _channelFactory(Uri.parse(wsUrl));
      _channel = channel;
      _subscription = channel.stream.listen(
        _handleFrame,
        onError: (_) => _handleDisconnect(),
        onDone: _handleDisconnect,
        cancelOnError: true,
      );

      channel.sink.add(
        jsonEncode({
          'type': 'subscribe',
          'tenantId': tenantId,
          'token': token,
        }),
      );
      _connected = true;
      _reconnectAttempt = 0;
      onConnectionStateChanged?.call(connected: true, reconnecting: false);
    } catch (_) {
      _handleDisconnect();
    }
  }

  void _handleFrame(dynamic frame) {
    if (frame is! String) return;
    try {
      final json = jsonDecode(frame) as Map<String, dynamic>;
      final message = LiveUpdateMessage.fromJson(json);
      onMessage?.call(message);
      if (message is LiveUpdateError) {
        _handleDisconnect();
      }
    } catch (_) {
      // Ignore malformed frames.
    }
  }

  void _handleDisconnect() {
    _connected = false;
    if (_stopped) {
      onConnectionStateChanged?.call(connected: false, reconnecting: false);
      return;
    }
    onConnectionStateChanged?.call(connected: false, reconnecting: true);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final delay = Duration(
      milliseconds: (baseReconnectDelay.inMilliseconds *
              (1 << _reconnectAttempt.clamp(0, 5)))
          .clamp(
        baseReconnectDelay.inMilliseconds,
        maxReconnectDelay.inMilliseconds,
      ),
    );
    _reconnectAttempt++;
    _reconnectTimer = Timer(delay, () {
      unawaited(_openChannel());
    });
  }
}
