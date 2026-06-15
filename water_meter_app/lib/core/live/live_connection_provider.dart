import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LiveConnectionStatus {
  idle,
  connecting,
  connected,
  reconnecting,
  disconnected,
}

class LiveConnectionState {
  const LiveConnectionState({
    required this.status,
    this.message,
  });

  const LiveConnectionState.idle() : this(status: LiveConnectionStatus.idle);

  final LiveConnectionStatus status;
  final String? message;

  bool get isConnected => status == LiveConnectionStatus.connected;

  bool get shouldShowBanner =>
      status == LiveConnectionStatus.reconnecting ||
      (status == LiveConnectionStatus.disconnected && message != null);

  LiveConnectionState copyWith({
    LiveConnectionStatus? status,
    String? message,
  }) {
    return LiveConnectionState(
      status: status ?? this.status,
      message: message ?? this.message,
    );
  }
}

class LiveConnectionNotifier extends Notifier<LiveConnectionState> {
  @override
  LiveConnectionState build() => const LiveConnectionState.idle();

  void setConnecting() {
    state = const LiveConnectionState(status: LiveConnectionStatus.connecting);
  }

  void setConnected() {
    state = const LiveConnectionState(status: LiveConnectionStatus.connected);
  }

  void setReconnecting() {
    state = const LiveConnectionState(
      status: LiveConnectionStatus.reconnecting,
      message: 'Reconnecting to live updates…',
    );
  }

  void setDisconnected({String? message}) {
    state = LiveConnectionState(
      status: LiveConnectionStatus.disconnected,
      message: message ?? 'Live updates disconnected',
    );
  }

  void setIdle() {
    state = const LiveConnectionState.idle();
  }
}

final liveConnectionStatusProvider =
    NotifierProvider<LiveConnectionNotifier, LiveConnectionState>(
  LiveConnectionNotifier.new,
);
