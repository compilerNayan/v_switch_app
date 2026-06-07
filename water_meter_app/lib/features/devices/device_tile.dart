import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/current_reading.dart';
import '../../core/models/user_device.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/control_providers.dart';
import '../../core/providers/device_providers.dart';
import '../../core/providers/device_tile_providers.dart';
import '../../core/utils/units.dart';

class DeviceTile extends ConsumerStatefulWidget {
  const DeviceTile({super.key, required this.device});

  final UserDevice device;

  @override
  ConsumerState<DeviceTile> createState() => _DeviceTileState();
}

class _DeviceTileState extends ConsumerState<DeviceTile> {
  bool _togglingValve = false;

  bool get _isWaterMeter => widget.device.typeId == 'water_meter';

  Future<void> _onValveToggle(bool turnOn) async {
    if (!ref.read(isDeviceAdminProvider) || _togglingValve) return;

    setState(() => _togglingValve = true);
    try {
      await toggleDeviceValveForId(ref, widget.device.deviceId);
    } finally {
      if (mounted) setState(() => _togglingValve = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final type = iconForDeviceType(widget.device.typeId);
    final typeName = type?.name ?? 'Device';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/devices/${widget.device.id}/dashboard'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.device.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_isWaterMeter) _ValveSwitch(
                    deviceId: widget.device.deviceId,
                    toggling: _togglingValve,
                    onChanged: _onValveToggle,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$typeName · ${widget.device.deviceId}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (_isWaterMeter) ...[
                const SizedBox(height: 12),
                _LiveReadingRow(deviceId: widget.device.deviceId),
                const SizedBox(height: 8),
                _QuotaUsageRow(deviceId: widget.device.deviceId),
              ],
              const Spacer(),
              Text(
                'Tap for details →',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.outline,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ValveSwitch extends ConsumerWidget {
  const _ValveSwitch({
    required this.deviceId,
    required this.toggling,
    required this.onChanged,
  });

  final String deviceId;
  final bool toggling;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isDeviceAdminProvider);
    final valveAsync = ref.watch(deviceValveProvider(deviceId));

    return valveAsync.when(
      data: (valve) => GestureDetector(
        onTap: () {},
        behavior: HitTestBehavior.opaque,
        child: Switch(
          value: !valve.isOff,
          onChanged: isAdmin && !toggling ? onChanged : null,
        ),
      ),
      loading: () => const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => const Icon(Icons.error_outline, size: 20),
    );
  }
}

class _LiveReadingRow extends ConsumerWidget {
  const _LiveReadingRow({required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readingAsync = ref.watch(deviceCurrentReadingProvider(deviceId));
    final valveAsync = ref.watch(deviceValveProvider(deviceId));
    final unit = ref.watch(volumeUnitProvider);

    return readingAsync.when(
      data: (reading) {
        final valveOff = valveAsync.valueOrNull?.isOff ?? false;
        final label = valveOff
            ? 'Water off'
            : '${VolumeFormatter.fromLiters(reading.flowRateLpm, unit).toStringAsFixed(1)} ${unit.symbol}/min';
        final color = valveOff
            ? Theme.of(context).colorScheme.outline
            : _statusColor(context, reading);

        return Row(
          children: [
            Icon(Icons.water_drop, size: 18, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ],
        );
      },
      loading: () => const _ShimmerLine(width: 120),
      error: (_, __) => _RetryRow(
        label: 'Flow unavailable',
        onRetry: () => ref.invalidate(deviceCurrentReadingProvider(deviceId)),
      ),
    );
  }

  Color _statusColor(BuildContext context, CurrentReading reading) {
    if (reading.status == WaterDeviceStatus.flowing) {
      return Theme.of(context).colorScheme.primary;
    }
    return Theme.of(context).colorScheme.outline;
  }
}

class _QuotaUsageRow extends ConsumerWidget {
  const _QuotaUsageRow({required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usageAsync = ref.watch(deviceTodayUsageProvider(deviceId));
    final quotaAsync = ref.watch(deviceQuotaProvider(deviceId));
    final unit = ref.watch(volumeUnitProvider);

    return usageAsync.when(
      data: (usedLiters) {
        final quota = quotaAsync.valueOrNull;
        if (quota != null && quota.enabled) {
          final progress = quota.dailyLimitLiters == 0
              ? 0.0
              : (usedLiters / quota.dailyLimitLiters).clamp(0.0, 1.0).toDouble();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${VolumeFormatter.format(usedLiters, unit, decimals: 0)} / '
                '${VolumeFormatter.format(quota.dailyLimitLiters, unit, decimals: 0)} today',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        }

        return Text(
          '${VolumeFormatter.format(usedLiters, unit, decimals: 0)} used today',
          style: Theme.of(context).textTheme.bodySmall,
        );
      },
      loading: () => const _ShimmerLine(width: 160),
      error: (_, __) => _RetryRow(
        label: 'Usage unavailable',
        onRetry: () {
          ref.invalidate(deviceTodayUsageProvider(deviceId));
          ref.invalidate(deviceQuotaProvider(deviceId));
        },
      ),
    );
  }
}

class _ShimmerLine extends StatelessWidget {
  const _ShimmerLine({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 14,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _RetryRow extends StatelessWidget {
  const _RetryRow({required this.label, required this.onRetry});

  final String label;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, size: 18),
          onPressed: onRetry,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class AddDeviceTile extends StatelessWidget {
  const AddDeviceTile({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline, size: 40, color: scheme.primary),
              const SizedBox(height: 8),
              Text(
                'Add device',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: scheme.primary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
