import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/v2_tenant_api_client.dart';
import '../config/app_config.dart';
import '../models/home_dashboard.dart';
import '../models/tenant_metadata.dart';
import '../utils/timezone_offset.dart';
import 'app_providers.dart';
import 'live_telemetry_patches_provider.dart';
import 'valve_patches_provider.dart';

final v2TenantApiClientProvider = Provider<V2TenantApiClient>((ref) {
  final auth = ref.watch(authServiceProvider);
  return V2TenantApiClient(authService: auth);
});

final usesV2HomeDataProvider = Provider<bool>((ref) => !AppConfig.useMockApi);

final homeSnapshotProvider =
    AsyncNotifierProvider<HomeSnapshotNotifier, HomeSnapshot?>(
  HomeSnapshotNotifier.new,
);

class HomeSnapshotNotifier extends AsyncNotifier<HomeSnapshot?> {
  @override
  Future<HomeSnapshot?> build() async {
    if (AppConfig.useMockApi) return null;

    final profile = await ref.watch(userProfileProvider.future);
    final tenantId = profile?.tenantId;
    if (tenantId == null || tenantId.isEmpty) return null;

    final prefs = await ref.watch(preferencesStorageProvider.future);
    final cached = prefs.getHomeSnapshot(tenantId);
    if (cached != null) {
      Future.microtask(() => refresh());
      return cached;
    }

    return _loadSnapshot();
  }

  Future<HomeSnapshot?> _loadSnapshot() async {
    if (AppConfig.useMockApi) return null;

    final profile = await ref.watch(userProfileProvider.future);
    final tenantId = profile?.tenantId;
    if (tenantId == null || tenantId.isEmpty) return null;

    final client = ref.watch(v2TenantApiClientProvider);
    final prefs = await ref.watch(preferencesStorageProvider.future);

    try {
      final dashboardFuture = client.getDashboard(
        tenantId,
        timezone: localTimezoneOffsetParam(),
      );
      var metadata = prefs.getTenantMetadataV2(tenantId);
      final dashboard = await dashboardFuture;

      if (metadata == null ||
          metadata.metadataHash != dashboard.metadataHash) {
        metadata = await client.getMetadata(tenantId);
        await prefs.setTenantMetadataV2(tenantId, metadata);
      }

      final snapshot = HomeSnapshot(metadata: metadata, dashboard: dashboard);
      await prefs.setHomeSnapshot(tenantId, snapshot);
      return snapshot;
    } catch (error) {
      final cached = prefs.getHomeSnapshot(tenantId);
      if (cached != null) {
        return cached;
      }
      final metadataOnly = prefs.getTenantMetadataV2(tenantId);
      if (metadataOnly != null) {
        return HomeSnapshot(
          metadata: metadataOnly,
          dashboard: const HomeDashboardResponse(
            metadataHash: '',
            generatedAt: '',
            devices: [],
          ),
        );
      }
      throw Exception('Failed to load home dashboard: $error');
    }
  }

  Future<void> refresh() async {
    if (!state.hasValue) {
      state = const AsyncLoading<HomeSnapshot?>();
    } else {
      state = const AsyncLoading<HomeSnapshot?>().copyWithPrevious(state);
    }
    state = await AsyncValue.guard(_loadSnapshot);
  }
}

final tenantMetadataFromSnapshotProvider = Provider<TenantMetadataResponse?>((ref) {
  return ref.watch(
    homeSnapshotProvider.select((async) => async.valueOrNull?.metadata),
  );
});

final deviceHomeTelemetryProvider =
    Provider.family<DashboardTelemetryDevice?, String>((ref, deviceId) {
  if (AppConfig.useMockApi) return null;

  final normalizedId = normalizeDeviceId(deviceId);
  final base = ref.watch(
    homeSnapshotProvider.select((async) {
      final snapshot = async.valueOrNull;
      if (snapshot == null) return null;
      final direct = snapshot.telemetryByDeviceId[deviceId.trim()];
      if (direct != null) return direct;
      for (final device in snapshot.dashboard.devices) {
        if (normalizeDeviceId(device.deviceId) == normalizedId) {
          return device;
        }
      }
      return null;
    }),
  );
  final patch = ref.watch(liveTelemetryPatchProvider(deviceId));
  final valvePatch = ref.watch(valvePatchProvider(deviceId));
  var merged = mergeTelemetryPatch(base, patch);
  if (merged != null && valvePatch != null) {
    merged = merged.copyWith(
      valveIsOff: valvePatch.isOff,
      valveOpenPercent: valvePatch.openPercent,
    );
  }
  return merged;
});

/// True only on the initial v2 snapshot load (not during background refresh).
final homeSnapshotLoadingProvider = Provider<bool>((ref) {
  if (AppConfig.useMockApi) return false;
  final async = ref.watch(homeSnapshotProvider);
  return async.isLoading && !async.hasValue;
});

final homeSnapshotErrorProvider = Provider<Object?>((ref) {
  if (AppConfig.useMockApi) return null;
  final async = ref.watch(homeSnapshotProvider);
  return async.hasError ? async.error : null;
});

/// Dashboard telemetry merged with live WebSocket patches (flow, today usage, presence).
final mergedTelemetryByDeviceProvider =
    Provider<Map<String, DashboardTelemetryDevice>>((ref) {
  if (AppConfig.useMockApi) return const {};

  final snapshot = ref.watch(homeSnapshotProvider).valueOrNull;
  if (snapshot == null) return const {};

  final patches = ref.watch(liveTelemetryPatchesProvider);
  final merged = <String, DashboardTelemetryDevice>{};

  for (final device in snapshot.dashboard.devices) {
    final patch = patches[normalizeDeviceId(device.deviceId)];
    final value = mergeTelemetryPatch(device, patch) ?? device;
    merged[device.deviceId.trim()] = value;
  }

  return merged;
});

void invalidateHomeData(WidgetRef ref) {
  ref.invalidate(homeSnapshotProvider);
}

void invalidateHomeDataFromRef(Ref ref) {
  ref.invalidate(homeSnapshotProvider);
}
