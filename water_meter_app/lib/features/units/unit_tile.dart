import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/home_dashboard.dart';
import '../../core/models/water_unit.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/control_providers.dart';
import '../../core/providers/dashboard_providers.dart';
import '../../core/providers/device_tile_providers.dart';
import '../../core/utils/contact_launcher.dart';
import '../../core/utils/units.dart';

class UnitTile extends ConsumerStatefulWidget {
  const UnitTile({super.key, required this.unit});

  final WaterUnit unit;

  @override
  ConsumerState<UnitTile> createState() => _UnitTileState();
}

class _UnitTileState extends ConsumerState<UnitTile> {
  bool _togglingValve = false;

  void _showNoPhoneMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No phone number on file. Add one in Edit unit.'),
      ),
    );
  }

  Future<void> _onCallPressed() async {
    final phone = widget.unit.phoneNumber;
    if (!hasCallablePhone(phone)) {
      _showNoPhoneMessage();
      return;
    }
    final launched = await launchPhoneCall(phone!);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start phone call')),
      );
    }
  }

  Future<void> _onWhatsAppPressed() async {
    final phone = widget.unit.phoneNumber;
    if (!hasCallablePhone(phone)) {
      _showNoPhoneMessage();
      return;
    }
    final launched = await launchWhatsAppChat(phone!);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp')),
      );
    }
  }

  Future<void> _onValveToggle(bool turnOn) async {
    if (!ref.read(isDeviceAdminProvider) || _togglingValve) return;
    if (widget.unit.maintenanceMode && turnOn) return;
    setState(() => _togglingValve = true);
    try {
      await toggleDeviceValveForId(ref, widget.unit.deviceId);
      invalidateHomeData(ref);
    } finally {
      if (mounted) setState(() => _togglingValve = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isAdmin = ref.watch(isDeviceAdminProvider);
    final isPending = widget.unit.isEnrollmentPending;
    final homeTelemetry =
        ref.watch(deviceHomeTelemetryProvider(widget.unit.deviceId));
    final healthAsync = isPending || homeTelemetry != null
        ? null
        : ref.watch(deviceHealthProvider(widget.unit.deviceId));
    final hasPhone = hasCallablePhone(widget.unit.phoneNumber);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/devices/${widget.unit.id}/dashboard'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isPending)
                    Icon(Icons.circle, size: 10, color: scheme.outline)
                  else
                    healthAsync!.when(
                      data: (h) => Icon(
                        Icons.circle,
                        size: 10,
                        color: h.isOnline ? Colors.green : scheme.outline,
                      ),
                      loading: () => const SizedBox(width: 10, height: 10),
                      error: (_, __) =>
                          Icon(Icons.circle, size: 10, color: scheme.error),
                    ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.unit.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isPending)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Enrolling…',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  if (isAdmin && !isPending) ...[
                    _ContactIconButton(
                      icon: Icons.phone_outlined,
                      tooltip: 'Call resident',
                      enabled: hasPhone,
                      onPressed: _onCallPressed,
                    ),
                    _ContactIconButton(
                      icon: Icons.chat_outlined,
                      tooltip: 'WhatsApp',
                      enabled: hasPhone,
                      onPressed: _onWhatsAppPressed,
                    ),
                  ],
                  if (isAdmin && !isPending)
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') {
                          context.push('/units/${widget.unit.id}/edit');
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit unit')),
                      ],
                    ),
                  if (isAdmin && !isPending)
                    _ValveSwitch(
                      deviceId: widget.unit.deviceId,
                      maintenanceMode: widget.unit.maintenanceMode,
                      toggling: _togglingValve,
                      valveIsOff: homeTelemetry?.valveIsOff,
                      onChanged: _onValveToggle,
                    ),
                ],
              ),
              if (widget.unit.maintenanceMode)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Maintenance mode',
                    style: TextStyle(
                      color: scheme.tertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                widget.unit.displaySubtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (isPending)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Enrollment in progress — readings unavailable',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                )
              else if (homeTelemetry != null)
                Text(
                  homeTelemetry.isOnline ? 'Online' : 'Offline',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: homeTelemetry.isOnline
                            ? Colors.green.shade700
                            : scheme.outline,
                      ),
                )
              else
                healthAsync!.when(
                  data: (h) => Text(
                    h.isOnline
                        ? 'Online'
                        : 'Last seen ${h.lastSeenLabel(DateTime.now())}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color:
                              h.isOnline ? Colors.green.shade700 : scheme.outline,
                        ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              if (!isPending) ...[
                const SizedBox(height: 12),
                _LiveReadingRow(
                  deviceId: widget.unit.deviceId,
                  homeTelemetry: homeTelemetry,
                ),
                const SizedBox(height: 8),
                _QuotaUsageRow(
                  deviceId: widget.unit.deviceId,
                  homeTelemetry: homeTelemetry,
                ),
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

class _ContactIconButton extends StatelessWidget {
  const _ContactIconButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      icon: Icon(
        icon,
        size: 20,
        color: enabled ? scheme.primary : scheme.outline,
      ),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: onPressed,
    );
  }
}

class _ValveSwitch extends ConsumerWidget {
  const _ValveSwitch({
    required this.deviceId,
    required this.maintenanceMode,
    required this.toggling,
    this.valveIsOff,
    required this.onChanged,
  });

  final String deviceId;
  final bool maintenanceMode;
  final bool toggling;
  final bool? valveIsOff;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isDeviceAdminProvider);
    if (valveIsOff != null) {
      return Switch(
        value: !valveIsOff!,
        onChanged: isAdmin && !toggling && !maintenanceMode ? onChanged : null,
      );
    }
    final valveAsync = ref.watch(deviceValveProvider(deviceId));
    return valveAsync.when(
      data: (valve) => Switch(
        value: !valve.isOff,
        onChanged: isAdmin && !toggling && !maintenanceMode ? onChanged : null,
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
  const _LiveReadingRow({
    required this.deviceId,
    this.homeTelemetry,
  });

  final String deviceId;
  final DashboardTelemetryDevice? homeTelemetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(volumeUnitProvider);
    if (homeTelemetry != null) {
      final valveOff = homeTelemetry!.valveIsOff;
      final flowRateLpm = homeTelemetry!.flowRateLpm;
      final label = valveOff
          ? 'Water off'
          : '${VolumeFormatter.fromLiters(flowRateLpm, unit).toStringAsFixed(1)} ${unit.symbol}/min';
      return Row(
        children: [
          Icon(
            Icons.water_drop,
            size: 18,
            color: valveOff
                ? Theme.of(context).colorScheme.outline
                : Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(label)),
        ],
      );
    }

    final readingAsync = ref.watch(deviceCurrentReadingProvider(deviceId));
    final valveAsync = ref.watch(deviceValveProvider(deviceId));
    return readingAsync.when(
      data: (reading) {
        final valveOff = valveAsync.valueOrNull?.isOff ?? false;
        final label = valveOff
            ? 'Water off'
            : '${VolumeFormatter.fromLiters(reading.flowRateLpm, unit).toStringAsFixed(1)} ${unit.symbol}/min';
        return Row(
          children: [
            Icon(Icons.water_drop, size: 18,
                color: valveOff
                    ? Theme.of(context).colorScheme.outline
                    : Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(child: Text(label)),
          ],
        );
      },
      loading: () => const _ShimmerLine(width: 120),
      error: (_, __) => const Text('Flow unavailable'),
    );
  }
}

class _QuotaUsageRow extends ConsumerWidget {
  const _QuotaUsageRow({
    required this.deviceId,
    this.homeTelemetry,
  });

  final String deviceId;
  final DashboardTelemetryDevice? homeTelemetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(volumeUnitProvider);
    if (homeTelemetry != null) {
      final used = homeTelemetry!.quotaUsedLiters;
      final quotaEnabled = homeTelemetry!.quotaEnabled;
      final dailyLimit = homeTelemetry!.dailyLimitLiters;
      if (quotaEnabled && dailyLimit > 0) {
        final progress = (used / dailyLimit).clamp(0.0, 1.0).toDouble();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: progress, minHeight: 6),
            ),
            const SizedBox(height: 4),
            Text(
              '${VolumeFormatter.format(used, unit, decimals: 0)} / '
              '${VolumeFormatter.format(dailyLimit, unit, decimals: 0)} today',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      }
      return Text(
        '${VolumeFormatter.format(used, unit, decimals: 0)} used today',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    final usageAsync = ref.watch(deviceTodayUsageProvider(deviceId));
    final quotaAsync = ref.watch(deviceQuotaProvider(deviceId));
    return usageAsync.when(
      data: (used) {
        final quota = quotaAsync.valueOrNull;
        if (quota != null && quota.enabled) {
          final progress = quota.dailyLimitLiters == 0
              ? 0.0
              : (used / quota.dailyLimitLiters).clamp(0.0, 1.0).toDouble();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: progress, minHeight: 6),
              ),
              const SizedBox(height: 4),
              Text(
                '${VolumeFormatter.format(used, unit, decimals: 0)} / '
                '${VolumeFormatter.format(quota.dailyLimitLiters, unit, decimals: 0)} today',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        }
        return Text(
          '${VolumeFormatter.format(used, unit, decimals: 0)} used today',
          style: Theme.of(context).textTheme.bodySmall,
        );
      },
      loading: () => const _ShimmerLine(width: 160),
      error: (_, __) => const Text('Usage unavailable'),
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

class AddUnitTile extends StatelessWidget {
  const AddUnitTile({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline, size: 40, color: scheme.primary),
              const SizedBox(height: 8),
              Text('Add water meter',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.primary,
                      )),
            ],
          ),
        ),
      ),
    );
  }
}
