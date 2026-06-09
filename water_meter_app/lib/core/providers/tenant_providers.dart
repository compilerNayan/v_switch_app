import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../models/tenant_config.dart';
import 'app_providers.dart';
import 'dashboard_providers.dart';

final tenantConfigProvider = FutureProvider<TenantConfig?>((ref) async {
  final profile = await ref.watch(userProfileProvider.future);
  final tenantId = profile?.tenantId;
  if (tenantId == null) return null;

  if (!AppConfig.useMockApi) {
    final snapshot = ref.watch(homeSnapshotProvider).valueOrNull;
    if (snapshot != null) {
      return snapshot.metadata.toTenantConfig();
    }
  }

  final prefs = await ref.watch(preferencesStorageProvider.future);
  final cached = prefs.getTenantConfig();
  final client = ref.watch(tenantApiClientProvider);

  try {
    return await client.getTenant(tenantId);
  } catch (_) {
    if (cached != null && cached.tenantId == tenantId) {
      return cached;
    }
    rethrow;
  }
});
