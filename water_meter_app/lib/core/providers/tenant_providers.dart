import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tenant_config.dart';
import 'app_providers.dart';

final tenantConfigProvider = FutureProvider<TenantConfig?>((ref) async {
  final profile = await ref.watch(userProfileProvider.future);
  final tenantId = profile?.tenantId;
  if (tenantId == null) return null;
  final client = ref.watch(tenantApiClientProvider);
  return client.getTenant(tenantId);
});
