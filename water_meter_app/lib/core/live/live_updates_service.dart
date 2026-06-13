import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../models/user_profile.dart';
import '../providers/app_providers.dart';
import '../providers/dashboard_providers.dart';
import '../providers/live_device_reading_provider.dart';
import '../providers/live_telemetry_patches_provider.dart';
import '../providers/unit_providers.dart';
import '../providers/water_providers.dart';
import 'live_update_message.dart';
import 'live_updates_debug_provider.dart';
import 'tenant_live_updates_client.dart';

final liveUpdatesServiceProvider = Provider<LiveUpdatesService>((ref) {
  final service = LiveUpdatesService(ref);
  ref.onDispose(service.dispose);
  return service;
});

/// Watches auth/profile and keeps the WebSocket lifecycle in sync.
final liveUpdatesBindingProvider = Provider<void>((ref) {
  final debug = ref.read(liveUpdatesDebugProvider.notifier);
  debug.setSocketEnabled(LiveUpdatesService.shouldEnable);
  if (!LiveUpdatesService.shouldEnable) {
    debug.setSocketConnected(false);
    return;
  }
  final service = ref.watch(liveUpdatesServiceProvider);
  ref.listen<AsyncValue<UserProfile?>>(userProfileProvider, (_, next) {
    service.onProfileChanged(next.valueOrNull);
  }, fireImmediately: true);
});

class LiveUpdatesService {
  LiveUpdatesService(this._ref);

  final Ref _ref;
  TenantLiveUpdatesClient? _client;
  String? _activeTenantId;

  static bool get shouldEnable =>
      !AppConfig.useMockApi &&
      AppConfig.liveUpdatesEnabled &&
      AppConfig.liveUpdatesWsUrl.isNotEmpty;

  void onProfileChanged(UserProfile? profile) {
    final tenantId = profile?.tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      _disconnect();
      return;
    }
    if (_activeTenantId == tenantId && _client?.isConnected == true) {
      return;
    }
    _connect(tenantId);
  }

  void dispose() {
    _disconnect();
  }

  Future<void> _connect(String tenantId) async {
    await _disconnect();
    _activeTenantId = tenantId;
    final auth = _ref.read(authServiceProvider);
    _ref.read(liveUpdatesDebugProvider.notifier).setSocketConnected(false);
    _client = TenantLiveUpdatesClient(
      wsUrl: AppConfig.liveUpdatesWsUrl,
      tenantId: tenantId,
      tokenProvider: auth.getIdToken,
      onMessage: _handleMessage,
      onSocketOpen: () {
        _ref.read(liveUpdatesDebugProvider.notifier).setSocketConnected(true);
      },
      onSocketClosed: () {
        _ref.read(liveUpdatesDebugProvider.notifier).setSocketConnected(false);
      },
    );
    await _client!.connect();
  }

  Future<void> _disconnect() async {
    await _client?.disconnect();
    _client = null;
    _activeTenantId = null;
    _ref.read(liveUpdatesDebugProvider.notifier).setSocketConnected(false);
  }

  void _handleMessage(LiveUpdateMessage message) {
    final debug = _ref.read(liveUpdatesDebugProvider.notifier);
    switch (message) {
      case LiveUpdateWaterFlow():
        debug.recordMessage(type: 'water_flow');
        _ref.read(liveTelemetryPatchesProvider.notifier).applyWaterFlow(message);
        _patchActiveDeviceReading(message);
      case LiveUpdateBucket30m():
        debug.recordMessage(type: 'bucket_30m');
        _ref.read(liveTelemetryPatchesProvider.notifier).clearDevice(message.deviceId);
        invalidateHomeDataFromRef(_ref);
        final activeDeviceId = _ref.read(activeDeviceApiIdProvider);
        if (activeDeviceId.trim().toUpperCase() ==
            message.deviceId.trim().toUpperCase()) {
          _ref.invalidate(currentReadingProvider);
          _ref.invalidate(usageResponseProvider);
        }
      case LiveUpdateSubscribed():
        debug.recordMessage(type: 'subscribed');
        debug.setSocketConnected(true);
      case LiveUpdateError(code: final errorCode, message: final errorMessage):
        debug.recordMessage(type: 'error', error: '$errorCode: $errorMessage');
        debug.setSocketConnected(false);
    }
  }

  void _patchActiveDeviceReading(LiveUpdateWaterFlow event) {
    final activeDeviceId = _ref.read(activeDeviceApiIdProvider).trim();
    if (activeDeviceId.toUpperCase() != event.deviceId.trim().toUpperCase()) {
      return;
    }
    _ref.read(liveDeviceReadingProvider.notifier).applyWaterFlow(event);
  }
}
