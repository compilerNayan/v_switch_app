import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/current_reading.dart';
import '../live/live_update_message.dart';

final liveDeviceReadingProvider =
    NotifierProvider<LiveDeviceReadingNotifier, CurrentReading?>(
  LiveDeviceReadingNotifier.new,
);

class LiveDeviceReadingNotifier extends Notifier<CurrentReading?> {
  @override
  CurrentReading? build() => null;

  void applyWaterFlow(LiveUpdateWaterFlow event) {
    state = CurrentReading(
      deviceId: event.deviceId,
      timestamp: DateTime.tryParse(event.ts) ?? DateTime.now(),
      flowRateLpm: event.flowRateLpm,
      cumulativeLiters: state?.cumulativeLiters ?? 0,
      status: event.status == 'flowing'
          ? WaterDeviceStatus.flowing
          : WaterDeviceStatus.idle,
    );
  }

  void clear() {
    state = null;
  }
}
