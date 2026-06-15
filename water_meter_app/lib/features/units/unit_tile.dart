import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/models/device_health.dart';
import '../../core/models/home_dashboard.dart';
import '../../core/models/water_unit.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/control_providers.dart';
import '../../core/providers/dashboard_providers.dart';
import '../../core/providers/device_tile_providers.dart';
import '../../core/providers/live_telemetry_patches_provider.dart';
import '../../core/utils/contact_launcher.dart';
import '../../core/utils/units.dart';
import '../../shared/widgets/flow_status_indicator.dart';
import '../../shared/widgets/location_tag_chips.dart';

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
      await setDeviceValveForId(
        ref,
        widget.unit.deviceId,
        turnOn: turnOn,
      );
      invalidateHomeData(ref);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Valve control failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _togglingValve = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isDeviceAdminProvider);
    final isPending = widget.unit.isEnrollmentPending;
    final usesV2Home = !AppConfig.useMockApi;
    final homeSnapshotLoading = ref.watch(homeSnapshotLoadingProvider);
    final homeTelemetry =
        ref.watch(deviceHomeTelemetryProvider(widget.unit.deviceId));
    final usePerDeviceApis = !usesV2Home;
    final showTelemetryLoading =
        usesV2Home && homeSnapshotLoading && homeTelemetry == null;
    final healthAsync = !usesV2Home && !isPending && homeTelemetry == null
        ? ref.watch(deviceHealthProvider(widget.unit.deviceId))
        : null;
    final hasPhone = hasCallablePhone(widget.unit.phoneNumber);
    final hasTags = widget.unit.locationTagEntries.isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.go('/devices/${widget.unit.id}/dashboard'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isPending) _PendingSerialBadge(deviceId: widget.unit.deviceId),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _UnitTileHeader(
                      unit: widget.unit,
                      isPending: isPending,
                      isAdmin: isAdmin,
                      hasPhone: hasPhone,
                      usesV2Home: usesV2Home,
                      homeTelemetry: homeTelemetry,
                      healthAsync: healthAsync,
                      usePerDeviceApis: usePerDeviceApis,
                      homeSnapshotLoading: showTelemetryLoading,
                      togglingValve: _togglingValve,
                      onCall: _onCallPressed,
                      onWhatsApp: _onWhatsAppPressed,
                      onValveToggle: _onValveToggle,
                    ),
                    if (widget.unit.maintenanceMode)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Maintenance mode',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.tertiary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    if (hasTags) ...[
                      const SizedBox(height: 6),
                      LocationTagChips(unit: widget.unit),
                    ],
                    if (isPending) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Enrollment in progress',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      _UnitTelemetryStrip(
                        deviceId: widget.unit.deviceId,
                        homeTelemetry: homeTelemetry,
                        homeSnapshotLoading: showTelemetryLoading,
                        usePerDeviceApis: usePerDeviceApis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingSerialBadge extends StatelessWidget {
  const _PendingSerialBadge({required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Container(
        constraints: const BoxConstraints(minWidth: 52),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          deviceId,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
                height: 1.15,
              ),
        ),
      ),
    );
  }
}

class _UnitTileHeader extends StatelessWidget {
  const _UnitTileHeader({
    required this.unit,
    required this.isPending,
    required this.isAdmin,
    required this.hasPhone,
    required this.usesV2Home,
    required this.homeTelemetry,
    required this.healthAsync,
    required this.usePerDeviceApis,
    required this.homeSnapshotLoading,
    required this.togglingValve,
    required this.onCall,
    required this.onWhatsApp,
    required this.onValveToggle,
  });

  final WaterUnit unit;
  final bool isPending;
  final bool isAdmin;
  final bool hasPhone;
  final bool usesV2Home;
  final DashboardTelemetryDevice? homeTelemetry;
  final AsyncValue<DeviceHealth>? healthAsync;
  final bool usePerDeviceApis;
  final bool homeSnapshotLoading;
  final bool togglingValve;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  final ValueChanged<bool> onValveToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _OnlineDot(
          isPending: isPending,
          usesV2Home: usesV2Home,
          homeTelemetry: homeTelemetry,
          healthAsync: healthAsync,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            unit.topConsumerTitle,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isPending)
          Container(
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Enrolling',
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
            onPressed: onCall,
          ),
          _ContactIconButton(
            icon: Icons.chat_outlined,
            tooltip: 'WhatsApp',
            enabled: hasPhone,
            onPressed: onWhatsApp,
          ),
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            iconSize: 20,
            onSelected: (v) {
              if (v == 'edit') {
                context.push('/units/${unit.id}/edit');
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit unit')),
            ],
          ),
          _ValveSwitch(
            deviceId: unit.deviceId,
            maintenanceMode: unit.maintenanceMode,
            toggling: togglingValve,
            valveIsOff: homeTelemetry?.valveIsOff,
            usePerDeviceApis: usePerDeviceApis,
            homeSnapshotLoading: homeSnapshotLoading,
            onChanged: onValveToggle,
          ),
        ],
      ],
    );
  }
}

class _OnlineDot extends StatelessWidget {
  const _OnlineDot({
    required this.isPending,
    required this.usesV2Home,
    required this.homeTelemetry,
    required this.healthAsync,
  });

  final bool isPending;
  final bool usesV2Home;
  final DashboardTelemetryDevice? homeTelemetry;
  final AsyncValue<DeviceHealth>? healthAsync;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color color = scheme.outline;

    if (isPending) {
      color = scheme.outline;
    } else if (usesV2Home) {
      color = homeTelemetry?.isOnline == true ? Colors.green : scheme.outline;
    } else if (healthAsync != null) {
      return healthAsync!.when(
        data: (h) => Icon(
          Icons.circle,
          size: 9,
          color: h.isOnline ? Colors.green : scheme.outline,
        ),
        loading: () => const SizedBox(width: 9, height: 9),
        error: (_, __) => Icon(Icons.circle, size: 9, color: scheme.error),
      );
    }

    return Icon(Icons.circle, size: 9, color: color);
  }
}

class _UnitTelemetryStrip extends ConsumerWidget {
  const _UnitTelemetryStrip({
    required this.deviceId,
    this.homeTelemetry,
    this.homeSnapshotLoading = false,
    this.usePerDeviceApis = true,
  });

  final String deviceId;
  final DashboardTelemetryDevice? homeTelemetry;
  final bool homeSnapshotLoading;
  final bool usePerDeviceApis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.2,
    );

    if (homeSnapshotLoading) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShimmerLine(width: double.infinity),
          SizedBox(height: 6),
          _ShimmerLine(width: 120),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _FlowSnippet(
              deviceId: deviceId,
              homeTelemetry: homeTelemetry,
              usePerDeviceApis: usePerDeviceApis,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('·', style: muted),
            ),
            Expanded(
              child: _ReadingSnippet(
                deviceId: deviceId,
                usePerDeviceApis: usePerDeviceApis,
                style: muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _QuotaSnippet(
          deviceId: deviceId,
          homeTelemetry: homeTelemetry,
          usePerDeviceApis: usePerDeviceApis,
        ),
      ],
    );
  }
}

class _FlowSnippet extends ConsumerWidget {
  const _FlowSnippet({
    required this.deviceId,
    this.homeTelemetry,
    this.usePerDeviceApis = true,
  });

  final String deviceId;
  final DashboardTelemetryDevice? homeTelemetry;
  final bool usePerDeviceApis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(volumeUnitProvider);

    if (homeTelemetry != null) {
      return _flowRow(
        context,
        valveOff: homeTelemetry!.valveIsOff,
        flowRateLpm: homeTelemetry!.flowRateLpm,
        status: homeTelemetry!.status,
        volumeUnit: unit,
      );
    }

    if (!usePerDeviceApis) {
      return _flowRow(
        context,
        valveOff: true,
        flowRateLpm: 0,
        status: 'idle',
        volumeUnit: unit,
      );
    }

    final readingAsync = ref.watch(deviceCurrentReadingProvider(deviceId));
    final valveAsync = ref.watch(deviceValveProvider(deviceId));
    return readingAsync.when(
      data: (reading) => _flowRow(
        context,
        valveOff: valveAsync.valueOrNull?.isOff ?? false,
        flowRateLpm: reading.flowRateLpm,
        status: reading.status.name,
        volumeUnit: unit,
      ),
      loading: () => const _ShimmerLine(width: 72),
      error: (_, __) => const Text('—', style: TextStyle(fontSize: 12)),
    );
  }

  Widget _flowRow(
    BuildContext context, {
    required bool valveOff,
    required double flowRateLpm,
    required String status,
    required VolumeUnit volumeUnit,
  }) {
    final flowing = isWaterFlowing(
      valveOff: valveOff,
      flowRateLpm: flowRateLpm,
      status: status,
    );
    final label = valveOff
        ? 'Off'
        : '${VolumeFormatter.fromLiters(flowRateLpm, volumeUnit).toStringAsFixed(1)} ${volumeUnit.symbol}/m';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FlowStatusIndicator(isFlowing: flowing, size: 16),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.2),
        ),
      ],
    );
  }
}

class _ReadingSnippet extends ConsumerWidget {
  const _ReadingSnippet({
    required this.deviceId,
    this.usePerDeviceApis = true,
    this.style,
  });

  final String deviceId;
  final bool usePerDeviceApis;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patch = ref.watch(liveTelemetryPatchProvider(deviceId));
    final cumulative = patch?.cumulativeLiters;
    if (cumulative != null && cumulative > 0) {
      return _text(ref, cumulative);
    }

    if (!usePerDeviceApis) return const SizedBox.shrink();

    final readingAsync = ref.watch(deviceCurrentReadingProvider(deviceId));
    return readingAsync.when(
      data: (reading) => _text(ref, reading.cumulativeLiters),
      loading: () => const _ShimmerLine(width: 100),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _text(WidgetRef ref, double liters) {
    final unit = ref.watch(volumeUnitProvider);
    return Text(
      VolumeFormatter.format(liters, unit, decimals: 2),
      style: style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _QuotaSnippet extends ConsumerWidget {
  const _QuotaSnippet({
    required this.deviceId,
    this.homeTelemetry,
    this.usePerDeviceApis = true,
  });

  final String deviceId;
  final DashboardTelemetryDevice? homeTelemetry;
  final bool usePerDeviceApis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(volumeUnitProvider);
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          height: 1.2,
        );

    if (homeTelemetry != null) {
      return _quotaFromValues(
        context,
        used: homeTelemetry!.todayLiters,
        quotaEnabled: homeTelemetry!.quotaEnabled,
        dailyLimit: homeTelemetry!.dailyLimitLiters,
        unit: unit,
        labelStyle: labelStyle,
      );
    }

    if (!usePerDeviceApis) {
      return _quotaFromValues(
        context,
        used: 0,
        quotaEnabled: false,
        dailyLimit: 0,
        unit: unit,
        labelStyle: labelStyle,
      );
    }

    final usageAsync = ref.watch(deviceTodayUsageProvider(deviceId));
    final quotaAsync = ref.watch(deviceQuotaProvider(deviceId));
    return usageAsync.when(
      data: (used) {
        final quota = quotaAsync.valueOrNull;
        return _quotaFromValues(
          context,
          used: used,
          quotaEnabled: quota?.enabled ?? false,
          dailyLimit: quota?.dailyLimitLiters ?? 0,
          unit: unit,
          labelStyle: labelStyle,
        );
      },
      loading: () => const _ShimmerLine(width: 140),
      error: (_, __) => Text('Usage unavailable', style: labelStyle),
    );
  }

  Widget _quotaFromValues(
    BuildContext context, {
    required double used,
    required bool quotaEnabled,
    required double dailyLimit,
    required VolumeUnit unit,
    required TextStyle? labelStyle,
  }) {
    final hasQuota = quotaEnabled && dailyLimit > 0;
    final progress =
        hasQuota ? (used / dailyLimit).clamp(0.0, 1.0).toDouble() : null;
    final usageLabel = hasQuota
        ? '${VolumeFormatter.format(used, unit, decimals: 0)} / '
            '${VolumeFormatter.format(dailyLimit, unit, decimals: 0)} today'
        : '${VolumeFormatter.format(used, unit, decimals: 0)} today';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (progress != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(value: progress, minHeight: 3),
          ),
        if (progress != null) const SizedBox(height: 4),
        Text(usageLabel, style: labelStyle),
      ],
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
        size: 18,
        color: enabled ? scheme.primary : scheme.outline,
      ),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
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
    this.usePerDeviceApis = true,
    this.homeSnapshotLoading = false,
    required this.onChanged,
  });

  final String deviceId;
  final bool maintenanceMode;
  final bool toggling;
  final bool? valveIsOff;
  final bool usePerDeviceApis;
  final bool homeSnapshotLoading;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isDeviceAdminProvider);
    if (homeSnapshotLoading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (valveIsOff != null || !usePerDeviceApis) {
      final isOff = valveIsOff ?? true;
      return Transform.scale(
        scale: 0.82,
        child: Switch(
          value: !isOff,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onChanged:
              isAdmin && !toggling && !maintenanceMode ? onChanged : null,
        ),
      );
    }
    final valveAsync = ref.watch(deviceValveProvider(deviceId));
    return valveAsync.when(
      data: (valve) => Transform.scale(
        scale: 0.82,
        child: Switch(
          value: !valve.isOff,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onChanged:
              isAdmin && !toggling && !maintenanceMode ? onChanged : null,
        ),
      ),
      loading: () => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => const Icon(Icons.error_outline, size: 18),
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
      height: 12,
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
        child: SizedBox(
          height: 88,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_circle_outline, size: 22, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Add water meter',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.primary,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
