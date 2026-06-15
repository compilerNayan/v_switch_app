import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../models/user_profile.dart';
import '../providers/app_providers.dart';
import '../providers/dashboard_providers.dart';
import '../providers/live_telemetry_patches_provider.dart';
import '../providers/unit_providers.dart';
import '../providers/water_providers.dart';
import 'live_connection_provider.dart';
import 'live_update_message.dart';
import 'tenant_live_updates_client.dart';

final liveUpdatesServiceProvider = Provider<LiveUpdatesService>((ref) {
  final service = LiveUpdatesService(ref);
  ref.onDispose(service.dispose);
  return service;
});

/// Watches auth/profile and keeps the WebSocket lifecycle in sync.
final liveUpdatesBindingProvider = Provider<void>((ref) {
  if (!LiveUpdatesService.shouldEnable) {
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

  Future<void> reconnect() async {
    final tenantId = _activeTenantId;
    if (tenantId == null || tenantId.isEmpty) {
      final profile = _ref.read(userProfileProvider).valueOrNull;
      if (profile?.tenantId == null || profile!.tenantId!.isEmpty) return;
      await _connect(profile.tenantId!);
      return;
    }
    await _client?.reconnectNow();
  }

  void dispose() {
    _disconnect();
  }

  Future<void> _connect(String tenantId) async {
    await _disconnect();
    _activeTenantId = tenantId;
    final auth = _ref.read(authServiceProvider);
    _ref.read(liveConnectionStatusProvider.notifier).setConnecting();
    _client = TenantLiveUpdatesClient(
      wsUrl: AppConfig.liveUpdatesWsUrl,
      tenantId: tenantId,
      tokenProvider: auth.getIdToken,
      onMessage: _handleMessage,
      onConnectionStateChanged: _handleConnectionState,
    );
    await _client!.connect();
  }

  Future<void> _disconnect() async {
    await _client?.disconnect();
    _client = null;
    _activeTenantId = null;
    _ref.read(liveConnectionStatusProvider.notifier).setIdle();
  }

  void _handleConnectionState({
    required bool connected,
    required bool reconnecting,
  }) {
    final notifier = _ref.read(liveConnectionStatusProvider.notifier);
    if (connected) {
      notifier.setConnected();
      return;
    }
    if (reconnecting) {
      notifier.setReconnecting();
      return;
    }
    notifier.setDisconnected();
  }

  void _handleMessage(LiveUpdateMessage message) {
    switch (message) {
      case LiveUpdateWaterFlow():
        _ref.read(liveTelemetryPatchesProvider.notifier).applyWaterFlow(message);
      case LiveUpdateDevicePresence():
        _ref.read(liveTelemetryPatchesProvider.notifier).applyDevicePresence(message);
      case LiveUpdateBucket30m():
        _ref.read(liveTelemetryPatchesProvider.notifier).clearDevice(message.deviceId);
        invalidateHomeDataFromRef(_ref);
        final activeDeviceId = _ref.read(activeDeviceApiIdProvider);
        if (activeDeviceId.trim().toUpperCase() ==
            message.deviceId.trim().toUpperCase()) {
          _ref.invalidate(currentReadingProvider);
          _ref.invalidate(usageResponseProvider);
        }
      case LiveUpdateSubscribed():
        _ref.read(liveConnectionStatusProvider.notifier).setConnected();
      case LiveUpdateError():
        break;
    }
  }
}
