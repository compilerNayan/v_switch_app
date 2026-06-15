import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/live/live_connection_provider.dart';
import '../../core/live/live_updates_service.dart';

/// Persistent inline banner when the app WebSocket is disconnected or reconnecting.
class LiveConnectionBanner extends ConsumerWidget {
  const LiveConnectionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(liveConnectionStatusProvider);
    if (!connection.shouldShowBanner) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final isReconnecting =
        connection.status == LiveConnectionStatus.reconnecting;
    final message = connection.message ??
        (isReconnecting
            ? 'Reconnecting to live updates…'
            : 'Live updates disconnected');

    return Material(
      color: scheme.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                isReconnecting ? Icons.sync : Icons.cloud_off_outlined,
                color: scheme.onErrorContainer,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: scheme.onErrorContainer,
                    fontSize: 13,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => ref.read(liveUpdatesServiceProvider).reconnect(),
                child: Text(
                  'Retry',
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows a brief snackbar when the WebSocket reconnects after a drop.
void listenForLiveConnectionSnackbars(BuildContext context, WidgetRef ref) {
  ref.listen<LiveConnectionState>(liveConnectionStatusProvider, (previous, next) {
    if (!context.mounted) return;
    if (next.isConnected && previous != null && !previous.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Live updates connected'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  });
}
