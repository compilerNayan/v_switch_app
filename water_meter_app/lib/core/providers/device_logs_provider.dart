import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../live/live_update_message.dart';
import '../providers/app_providers.dart';

class DeviceLogLine {
  const DeviceLogLine({
    required this.seq,
    required this.ts,
    required this.message,
    this.receivedAt,
  });

  final int seq;
  final String ts;
  final String message;
  final String? receivedAt;

  String get displayText {
    final prefix = ts.isNotEmpty ? '$ts ' : '';
    return '$prefix$message';
  }

  factory DeviceLogLine.fromEntry(DeviceLogEntryMessage entry) {
    return DeviceLogLine(
      seq: entry.seq,
      ts: entry.ts,
      message: entry.message,
      receivedAt: entry.receivedAt,
    );
  }
}

class DeviceLogsState {
  const DeviceLogsState({
    this.lines = const [],
    this.lastSeq = 0,
  });

  final List<DeviceLogLine> lines;
  final int lastSeq;

  DeviceLogsState copyWith({
    List<DeviceLogLine>? lines,
    int? lastSeq,
  }) {
    return DeviceLogsState(
      lines: lines ?? this.lines,
      lastSeq: lastSeq ?? this.lastSeq,
    );
  }
}

class DeviceLogsNotifier extends StateNotifier<DeviceLogsState> {
  DeviceLogsNotifier(this._ref, this._deviceId) : super(const DeviceLogsState());

  final Ref _ref;
  final String _deviceId;

  Future<void> loadPersistedLastSeq() async {
    final prefs = await _ref.read(preferencesStorageProvider.future);
    final lastSeq = prefs.getDeviceLogLastSeq(_deviceId);
    if (lastSeq > 0) {
      state = state.copyWith(lastSeq: lastSeq);
    }
  }

  void applyDeviceLog(LiveUpdateDeviceLog message) {
    if (!_matchesDevice(message.deviceId)) return;
    _mergeEntries([DeviceLogLine.fromEntry(DeviceLogEntryMessage(
      seq: message.seq,
      ts: message.ts,
      message: message.message,
      receivedAt: message.receivedAt,
      serialNumber: message.serialNumber,
    ))]);
  }

  void applyDeviceLogBatch(LiveUpdateDeviceLogBatch message) {
    if (!_matchesDevice(message.deviceId)) return;
    _mergeEntries(
      message.entries.map(DeviceLogLine.fromEntry).toList(),
    );
  }

  void applyDeviceLogReset(LiveUpdateDeviceLogReset message) {
    if (!_matchesDevice(message.deviceId)) return;
    state = DeviceLogsState(lastSeq: message.nextSeq - 1);
    _persistLastSeq(state.lastSeq);
  }

  void _mergeEntries(List<DeviceLogLine> incoming) {
    if (incoming.isEmpty) return;
    final bySeq = <int, DeviceLogLine>{
      for (final line in state.lines) line.seq: line,
    };
    for (final line in incoming) {
      if (line.seq > 0) {
        bySeq[line.seq] = line;
      }
    }
    final merged = bySeq.values.toList()
      ..sort((a, b) => a.seq.compareTo(b.seq));
    final lastSeq = merged.isEmpty ? state.lastSeq : merged.last.seq;
    state = state.copyWith(lines: merged, lastSeq: lastSeq);
    _persistLastSeq(lastSeq);
  }

  bool _matchesDevice(String deviceId) {
    return deviceId.trim().toUpperCase() == _deviceId.trim().toUpperCase();
  }

  void _persistLastSeq(int lastSeq) {
    unawaited(
      _ref.read(preferencesStorageProvider.future).then(
            (prefs) => prefs.setDeviceLogLastSeq(_deviceId, lastSeq),
          ),
    );
  }
}

final deviceLogsProvider = StateNotifierProvider.family<
    DeviceLogsNotifier, DeviceLogsState, String>((ref, deviceId) {
  return DeviceLogsNotifier(ref, deviceId);
});
