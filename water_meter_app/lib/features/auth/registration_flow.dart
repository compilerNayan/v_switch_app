import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/pending_registration.dart';
import '../../core/config/app_config.dart';
import '../../core/providers/app_providers.dart';

Future<void> savePendingRegistration(
  WidgetRef ref,
  PendingRegistration pending,
) async {
  ref.read(pendingRegistrationProvider.notifier).state = pending;
  if (AppConfig.useMockAuth) return;
  final prefs = await ref.read(preferencesStorageProvider.future);
  await prefs.setPendingRegistration(pending);
}

Future<PendingRegistration?> loadPendingRegistration(WidgetRef ref) async {
  final inMemory = ref.read(pendingRegistrationProvider);
  if (inMemory != null) return inMemory;
  if (AppConfig.useMockAuth) return null;
  final prefs = await ref.read(preferencesStorageProvider.future);
  final saved = prefs.getPendingRegistration();
  if (saved != null) {
    ref.read(pendingRegistrationProvider.notifier).state = saved;
  }
  return saved;
}

Future<void> clearPendingRegistration(WidgetRef ref) async {
  ref.read(pendingRegistrationProvider.notifier).state = null;
  if (AppConfig.useMockAuth) return;
  final prefs = await ref.read(preferencesStorageProvider.future);
  await prefs.setPendingRegistration(null);
}
