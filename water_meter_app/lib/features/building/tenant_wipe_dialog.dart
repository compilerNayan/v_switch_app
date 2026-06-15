import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exceptions.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/tenant_wipe_service.dart';

Future<void> showTenantWipeDialog(BuildContext context, WidgetRef ref) async {
  final profile = ref.read(userProfileProvider).valueOrNull;
  final wipeService = ref.read(tenantWipeServiceProvider);

  try {
    wipeService.ensureCanWipe(profile);
  } on ApiException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.error.message)),
    );
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text('Wipe this building?'),
        content: const Text(
          'This permanently deletes the building, all meters, usage history, '
          'and your account from the server. This cannot be undone.\n\n'
          'You will need to sign up again with a new account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Wipe everything'),
          ),
        ],
      );
    },
  );

  if (confirmed != true || !context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator()),
    ),
  );

  try {
    await wipeService.wipeTenant(profile!);
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    context.go('/auth?signup=1');
  } catch (e, stack) {
    debugPrint('Tenant wipe failed: $e');
    debugPrint('$stack');
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_wipeErrorMessage(e)),
        duration: const Duration(seconds: 8),
      ),
    );
  }
}

String _wipeErrorMessage(Object e) {
  if (e is ApiException) return e.error.message;
  if (e is NetworkException) return e.message;
  return 'Could not wipe tenant: $e';
}
