import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/v2_tenant_api_client.dart';
import '../config/app_config.dart';
import '../models/home_dashboard.dart';
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

  var metadata = prefs.getTenantMetadataV2(tenantId);
  final dashboard = await client.getDashboard(tenantId);

  if (metadata == null) {
    metadata = await client.getMetadata(tenantId);
    await prefs.setTenantMetadataV2(tenantId, metadata);
  } else if (metadata.metadataHash != dashboard.metadataHash) {
    unawaited(_refreshMetadataInBackground(ref, tenantId));
  }

  return HomeSnapshot(metadata: metadata, dashboard: dashboard);
});

Future<void> _refreshMetadataInBackground(Ref ref, String tenantId) async {
  try {
    final client = ref.read(v2TenantApiClientProvider);
    final prefs = await ref.read(preferencesStorageProvider.future);
    final metadata = await client.getMetadata(tenantId);
    await prefs.setTenantMetadataV2(tenantId, metadata);
    ref.invalidate(homeSnapshotProvider);
  } catch (_) {}
}

final deviceHomeTelemetryProvider =
    Provider.family<DashboardTelemetryDevice?, String>((ref, deviceId) {
  if (AppConfig.useMockApi) return null;
  final snapshot = ref.watch(homeSnapshotProvider).valueOrNull;
  return snapshot?.telemetryByDeviceId[deviceId];
});

void invalidateHomeData(WidgetRef ref) {
  ref.invalidate(homeSnapshotProvider);
}

void invalidateHomeDataFromRef(Ref ref) {
  ref.invalidate(homeSnapshotProvider);
}
