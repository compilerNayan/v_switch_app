import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/api_exceptions.dart';
import '../../core/live/live_updates_service.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/device_logs_provider.dart';
import '../../core/providers/unit_providers.dart';
import '../../shared/widgets/device_scaffold_actions.dart';

class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _stickToBottom = true;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startWatching());
  }

  Future<void> _startWatching() async {
    final deviceId = ref.read(activeDeviceApiIdProvider);
    final notifier = ref.read(deviceLogsProvider(deviceId).notifier);
    await notifier.loadPersistedLastSeq();
    final lastSeq = ref.read(deviceLogsProvider(deviceId)).lastSeq;
    ref.read(liveUpdatesServiceProvider).watchDeviceLogs(
          deviceId,
          lastSeq: lastSeq,
        );
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    _stickToBottom = position.maxScrollExtent - position.pixels < 80;
  }

  void _scrollToBottomIfNeeded() {
    if (!_stickToBottom || !_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    ref.read(liveUpdatesServiceProvider).unwatchDeviceLogs();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _downloadLogs() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    final deviceId = ref.read(activeDeviceApiIdProvider);
    try {
      final bytes =
          await ref.read(waterApiClientProvider).downloadDeviceLogs(deviceId);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$deviceId-logs.ndjson');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '$deviceId logs',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.error.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceId = ref.watch(activeDeviceApiIdProvider);
    ref.listen<String>(activeDeviceApiIdProvider, (previous, next) {
      if (previous != null && previous != next) {
        unawaited(_startWatching());
      }
    });
    final logsState = ref.watch(deviceLogsProvider(deviceId));
    ref.listen<DeviceLogsState>(deviceLogsProvider(deviceId), (_, __) {
      _scrollToBottomIfNeeded();
    });

    final text = logsState.lines.isEmpty
        ? 'No logs yet.\n\nLive device logs appear here when the meter is connected and publishing.'
        : logsState.lines.map((line) => line.displayText).join('\n');

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            pinned: true,
            leading: const DeviceBackButton(),
            title: const DeviceScreenTitle(fallback: 'Logs'),
            actions: [
              IconButton(
                tooltip: 'Download full log file',
                onPressed: _downloading ? null : _downloadLogs,
                icon: _downloading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: SelectableText(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      height: 1.35,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
