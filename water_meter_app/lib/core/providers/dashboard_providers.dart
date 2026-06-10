import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/v2_tenant_api_client.dart';
import '../config/app_config.dart';
import '../models/home_dashboard.dart';
import '../utils/timezone_offset.dart';
import 'app_providers.dart';

final v2TenantApiClientProvider = Provider<V2TenantApiClient>((ref) {
  final auth = ref.watch(authServiceProvider);
  return V2TenantApiClient(authService: auth);
});

final usesV2HomeDataProvider = Provider<bool>((ref) => !AppConfig.useMockApi);

final homeSnapshotProvider = FutureProvider<HomeSnapshot?>((ref) async {
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

    return HomeSnapshot(metadata: metadata, dashboard: dashboard);
  } catch (error) {
    final cached = prefs.getTenantMetadataV2(tenantId);
    if (cached != null) {
      return HomeSnapshot(
        metadata: cached,
        dashboard: const HomeDashboardResponse(
          metadataHash: '',
          generatedAt: '',
          devices: [],
        ),
      );
    }
    throw Exception('Failed to load home dashboard: $error');
  }
});

final deviceHomeTelemetryProvider =
    Provider.family<DashboardTelemetryDevice?, String>((ref, deviceId) {
  if (AppConfig.useMockApi) return null;
  final snapshot = ref.watch(homeSnapshotProvider).valueOrNull;
  if (snapshot == null) return null;
  return snapshot.telemetryByDeviceId[deviceId.trim()];
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

void invalidateHomeData(WidgetRef ref) {
  ref.invalidate(homeSnapshotProvider);
}

void invalidateHomeDataFromRef(Ref ref) {
  ref.invalidate(homeSnapshotProvider);
}
