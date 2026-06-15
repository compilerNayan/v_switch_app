import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'live_telemetry_patches_provider.dart';

class ValvePatch {
  const ValvePatch({
    required this.isOff,
    required this.openPercent,
  });

  final bool isOff;
  final double openPercent;
}

final valvePatchesProvider =
    NotifierProvider<ValvePatchesNotifier, Map<String, ValvePatch>>(
  ValvePatchesNotifier.new,
);

class ValvePatchesNotifier extends Notifier<Map<String, ValvePatch>> {
  @override
  Map<String, ValvePatch> build() => const {};

  void apply(String deviceId, {required bool isOff, required double openPercent}) {
    final key = normalizeDeviceId(deviceId);
    final next = Map<String, ValvePatch>.from(state);
    next[key] = ValvePatch(isOff: isOff, openPercent: openPercent);
    state = next;
  }

  void clear(String deviceId) {
    final key = normalizeDeviceId(deviceId);
    if (!state.containsKey(key)) return;
    final next = Map<String, ValvePatch>.from(state);
    next.remove(key);
    state = next;
  }
}

final valvePatchProvider = Provider.family<ValvePatch?, String>((ref, deviceId) {
  final key = normalizeDeviceId(deviceId);
  return ref.watch(valvePatchesProvider.select((patches) => patches[key]));
});
