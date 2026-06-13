import 'package:flutter_riverpod/flutter_riverpod.dart';

final liveUpdatesDebugProvider =
    NotifierProvider<LiveUpdatesDebugNotifier, LiveUpdatesDebugState>(
  LiveUpdatesDebugNotifier.new,
);

class LiveUpdatesDebugState {
  const LiveUpdatesDebugState({
    this.socketEnabled = false,
    this.socketConnected = false,
    this.messagesReceived = 0,
    this.waterFlowReceived = 0,
    this.bucket30mReceived = 0,
    this.subscribedReceived = 0,
    this.errorReceived = 0,
    this.lastMessageType,
    this.lastMessageAt,
    this.lastError,
  });

  final bool socketEnabled;
  final bool socketConnected;
  final int messagesReceived;
  final int waterFlowReceived;
  final int bucket30mReceived;
  final int subscribedReceived;
  final int errorReceived;
  final String? lastMessageType;
  final DateTime? lastMessageAt;
  final String? lastError;

  LiveUpdatesDebugState copyWith({
    bool? socketEnabled,
    bool? socketConnected,
    int? messagesReceived,
    int? waterFlowReceived,
    int? bucket30mReceived,
    int? subscribedReceived,
    int? errorReceived,
    String? lastMessageType,
    DateTime? lastMessageAt,
    String? lastError,
    bool clearLastError = false,
  }) {
    return LiveUpdatesDebugState(
      socketEnabled: socketEnabled ?? this.socketEnabled,
      socketConnected: socketConnected ?? this.socketConnected,
      messagesReceived: messagesReceived ?? this.messagesReceived,
      waterFlowReceived: waterFlowReceived ?? this.waterFlowReceived,
      bucket30mReceived: bucket30mReceived ?? this.bucket30mReceived,
      subscribedReceived: subscribedReceived ?? this.subscribedReceived,
      errorReceived: errorReceived ?? this.errorReceived,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }
}

class LiveUpdatesDebugNotifier extends Notifier<LiveUpdatesDebugState> {
  @override
  LiveUpdatesDebugState build() => const LiveUpdatesDebugState();

  void setSocketEnabled(bool enabled) {
    state = state.copyWith(socketEnabled: enabled);
  }

  void setSocketConnected(bool connected) {
    state = state.copyWith(socketConnected: connected);
  }

  void recordMessage({
    required String type,
    String? error,
  }) {
    final now = DateTime.now();
    state = state.copyWith(
      messagesReceived: state.messagesReceived + 1,
      waterFlowReceived: type == 'water_flow'
          ? state.waterFlowReceived + 1
          : state.waterFlowReceived,
      bucket30mReceived: type == 'bucket_30m'
          ? state.bucket30mReceived + 1
          : state.bucket30mReceived,
      subscribedReceived: type == 'subscribed'
          ? state.subscribedReceived + 1
          : state.subscribedReceived,
      errorReceived:
          type == 'error' ? state.errorReceived + 1 : state.errorReceived,
      lastMessageType: type,
      lastMessageAt: now,
      lastError: error,
      clearLastError: error == null,
    );
  }
}
