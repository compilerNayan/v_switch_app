import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exceptions.dart';
import '../api/valve_actions.dart';
import '../models/quota_config.dart';
import '../models/user_profile.dart';
import '../models/valve_state.dart';
import 'app_providers.dart';
import 'device_providers.dart';

final isDeviceAdminProvider = Provider<bool>((ref) {
  final profile = ref.watch(userProfileProvider);
  return profile.maybeWhen(
    data: (p) => p?.role == UserRole.admin,
    orElse: () => false,
  );
});

final valveStateProvider = FutureProvider.autoDispose<ValveState>((ref) async {
  final client = ref.watch(waterApiClientProvider);
  final deviceId = ref.watch(activeDeviceApiIdProvider);
  return client.getValveState(deviceId);
});

final quotaStateProvider =
    FutureProvider.autoDispose<QuotaResponse>((ref) async {
  final client = ref.watch(waterApiClientProvider);
  final deviceId = ref.watch(activeDeviceApiIdProvider);
  return client.getQuota(deviceId);
});

class ValveControlNotifier extends AutoDisposeAsyncNotifier<ValveState> {
  @override
  Future<ValveState> build() async {
    final client = ref.watch(waterApiClientProvider);
    final deviceId = ref.watch(activeDeviceApiIdProvider);
    return client.getValveState(deviceId);
  }

  Future<void> setPressure(double percent) async {
    if (!ref.read(isDeviceAdminProvider)) return;

    final previous = state.valueOrNull;
    if (previous != null) {
      state = AsyncData(
        ValveState(
          deviceId: previous.deviceId,
          timestamp: previous.timestamp,
          targetPressurePercent: percent,
          actualPressurePercent: previous.actualPressurePercent,
          lastUserPressurePercent:
              percent > 0 ? percent : previous.lastUserPressurePercent,
          isOff: percent == 0,
          controlMode: previous.controlMode,
          quotaCapPercent: previous.quotaCapPercent,
          effectivePressurePercent: previous.effectivePressurePercent,
        ),
      );
    }

    state = const AsyncLoading<ValveState>().copyWithPrevious(state);
    try {
      final client = ref.read(waterApiClientProvider);
      final deviceId = ref.read(activeDeviceApiIdProvider);
      final updated = await setDeviceValvePressure(client, deviceId, percent);
      state = AsyncData(updated);
      ref.invalidate(quotaStateProvider);
    } catch (e, st) {
      state = AsyncError<ValveState>(e, st).copyWithPrevious(state);
    }
  }

  Future<void> togglePower() async {
    if (!ref.read(isDeviceAdminProvider)) return;

    final current = state.valueOrNull ?? await future;
    if (current.isOff) {
      await restorePressure();
    } else {
      await setPressure(0);
    }
  }

  Future<void> restorePressure() async {
    if (!ref.read(isDeviceAdminProvider)) return;

    final previous = state.valueOrNull;
    state = const AsyncLoading<ValveState>().copyWithPrevious(state);
    try {
      final client = ref.read(waterApiClientProvider);
      final deviceId = ref.read(activeDeviceApiIdProvider);
      final updated = await restoreDeviceValvePressure(client, deviceId);
      state = AsyncData(updated);
      ref.invalidate(quotaStateProvider);
    } catch (e, st) {
      state = AsyncError<ValveState>(e, st).copyWithPrevious(
        previous != null ? AsyncData(previous) : state,
      );
    }
  }
}

final valveControlNotifierProvider =
    AutoDisposeAsyncNotifierProvider<ValveControlNotifier, ValveState>(
  ValveControlNotifier.new,
);

class QuotaConfigDraft {
  const QuotaConfigDraft({
    required this.enabled,
    required this.dailyLimitLiters,
    required this.steps,
  });

  final bool enabled;
  final double dailyLimitLiters;
  final List<QuotaStep> steps;

  factory QuotaConfigDraft.fromResponse(QuotaResponse response) {
    return QuotaConfigDraft(
      enabled: response.enabled,
      dailyLimitLiters: response.dailyLimitLiters,
      steps: List<QuotaStep>.from(response.steps),
    );
  }

  QuotaUpdateRequest toRequest() => QuotaUpdateRequest(
        enabled: enabled,
        dailyLimitLiters: dailyLimitLiters,
        steps: steps,
      );
}

class QuotaConfigNotifier extends AutoDisposeNotifier<QuotaConfigDraft?> {
  @override
  QuotaConfigDraft? build() => null;

  void loadFrom(QuotaResponse response) {
    state = QuotaConfigDraft.fromResponse(response);
  }

  void setEnabled(bool enabled) {
    final current = state;
    if (current == null) return;
    state = QuotaConfigDraft(
      enabled: enabled,
      dailyLimitLiters: current.dailyLimitLiters,
      steps: current.steps,
    );
  }

  void setDailyLimit(double liters) {
    final current = state;
    if (current == null) return;
    state = QuotaConfigDraft(
      enabled: current.enabled,
      dailyLimitLiters: liters,
      steps: current.steps,
    );
  }

  void updateStep(int index, QuotaStep step) {
    final current = state;
    if (current == null || index < 0 || index >= current.steps.length) {
      return;
    }
    final steps = List<QuotaStep>.from(current.steps)..[index] = step;
    state = QuotaConfigDraft(
      enabled: current.enabled,
      dailyLimitLiters: current.dailyLimitLiters,
      steps: steps,
    );
  }

  void addStep() {
    final current = state;
    if (current == null) return;
    final lastThreshold = current.steps.isEmpty
        ? 100.0
        : current.steps.last.atLitersUsed + 100;
    state = QuotaConfigDraft(
      enabled: current.enabled,
      dailyLimitLiters: current.dailyLimitLiters,
      steps: [
        ...current.steps,
        QuotaStep(
          atLitersUsed: lastThreshold,
          action: QuotaStepAction.reducePressure,
          value: 10,
        ),
      ],
    );
  }

  void removeStep(int index) {
    final current = state;
    if (current == null || index < 0 || index >= current.steps.length) {
      return;
    }
    final steps = List<QuotaStep>.from(current.steps)..removeAt(index);
    state = QuotaConfigDraft(
      enabled: current.enabled,
      dailyLimitLiters: current.dailyLimitLiters,
      steps: steps,
    );
  }

  Future<void> save() async {
    final draft = state;
    if (draft == null) return;
    if (!ref.read(isDeviceAdminProvider)) {
      throw const ApiException(
        statusCode: 403,
        error: ApiError(
          code: 'FORBIDDEN',
          message: 'Only admins can update quota settings',
        ),
      );
    }

    final client = ref.read(waterApiClientProvider);
    final deviceId = ref.read(activeDeviceApiIdProvider);
    final updated = await client.updateQuota(deviceId, draft.toRequest());
    state = QuotaConfigDraft.fromResponse(updated);
    ref.invalidate(quotaStateProvider);
    ref.invalidate(valveStateProvider);
    ref.invalidate(valveControlNotifierProvider);
  }
}

final quotaConfigNotifierProvider =
    AutoDisposeNotifierProvider<QuotaConfigNotifier, QuotaConfigDraft?>(
  QuotaConfigNotifier.new,
);
