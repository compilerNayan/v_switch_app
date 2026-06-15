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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
    final resident = widget.unit.ownerLabel;
    final hasTags = widget.unit.locationTagEntries.isNotEmpty;
    final subtitle = isPending
        ? 'Enrollment in progress'
        : (resident ??
            (widget.unit.name != widget.unit.tileFlatLabel
                ? widget.unit.name
                : ''));

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: InkWell(
        onTap: () => context.go('/devices/${widget.unit.id}/dashboard'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 2, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: _StatusDot(
                      isPending: isPending,
                      usesV2Home: usesV2Home,
                      homeTelemetry: homeTelemetry,
                      healthAsync: healthAsync,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              isPending
                                  ? widget.unit.deviceId
                                  : widget.unit.tileFlatLabel,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1.0,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            if (hasTags) ...[
                              const SizedBox(width: 6),
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: LocationTagChips(
                                    unit: widget.unit,
                                    compact: true,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (subtitle.isNotEmpty || isAdmin)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  subtitle,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.0,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isAdmin && !isPending) ...[
                                _TileIconButton(
                                  icon: Icons.phone_outlined,
                                  tooltip: 'Call resident',
                                  enabled: hasPhone,
                                  onPressed: _onCallPressed,
                                ),
                                _TileIconButton(
                                  icon: Icons.chat_outlined,
                                  tooltip: 'WhatsApp',
                                  enabled: hasPhone,
                                  onPressed: _onWhatsAppPressed,
                                ),
                              ],
                              if (isAdmin)
                                PopupMenuButton<String>(
                                  icon: Icon(
                                    Icons.more_vert_rounded,
                                    size: 18,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  padding: EdgeInsets.zero,
                                  tooltip: 'Options',
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      context.push(
                                        '/units/${widget.unit.id}/edit',
                                      );
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit unit'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (isPending)
                    _StatusPill(
                      label: 'Enrolling',
                      background: scheme.secondaryContainer,
                      foreground: scheme.onSecondaryContainer,
                    ),
                  if (widget.unit.maintenanceMode && !isPending)
                    _StatusPill(
                      label: 'Maint.',
                      background: scheme.tertiaryContainer,
                      foreground: scheme.onTertiaryContainer,
                    ),
                  if (isAdmin && !isPending)
                    _ValveSwitch(
                      deviceId: widget.unit.deviceId,
                      maintenanceMode: widget.unit.maintenanceMode,
                      toggling: _togglingValve,
                      valveIsOff: homeTelemetry?.valveIsOff,
                      usePerDeviceApis: usePerDeviceApis,
                      homeSnapshotLoading: showTelemetryLoading,
                      onChanged: _onValveToggle,
                    ),
                ],
              ),
              if (!isPending) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: _MetricsRow(
                    deviceId: widget.unit.deviceId,
                    homeTelemetry: homeTelemetry,
                    homeSnapshotLoading: showTelemetryLoading,
                    usePerDeviceApis: usePerDeviceApis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TileIconButton extends StatelessWidget {
  const _TileIconButton({
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

class _StatusDot extends StatelessWidget {
  const _StatusDot({
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

    if (isPending) {
      return Icon(Icons.circle, size: 8, color: scheme.outline);
    }
    if (usesV2Home) {
      final online = homeTelemetry?.isOnline == true;
      return Icon(
        Icons.circle,
        size: 8,
        color: online ? const Color(0xFF2E7D32) : scheme.outline,
      );
    }
    if (healthAsync != null) {
      return healthAsync!.when(
        data: (h) => Icon(
          Icons.circle,
          size: 8,
          color: h.isOnline ? const Color(0xFF2E7D32) : scheme.outline,
        ),
        loading: () => const SizedBox(width: 8, height: 8),
        error: (_, __) => Icon(Icons.circle, size: 8, color: scheme.error),
      );
    }
    return Icon(Icons.circle, size: 8, color: scheme.outline);
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _MetricsRow extends ConsumerWidget {
  const _MetricsRow({
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
    if (homeSnapshotLoading) {
      return const Row(
        children: [
          Expanded(child: _MetricSkeleton()),
          SizedBox(width: 4),
          Expanded(child: _MetricSkeleton()),
          SizedBox(width: 4),
          Expanded(child: _MetricSkeleton()),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 4,
          child: _FlowMetric(
            deviceId: deviceId,
            homeTelemetry: homeTelemetry,
            usePerDeviceApis: usePerDeviceApis,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          flex: 4,
          child: _ReadingMetric(
            deviceId: deviceId,
            usePerDeviceApis: usePerDeviceApis,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          flex: 3,
          child: _TodayMetric(
            deviceId: deviceId,
            homeTelemetry: homeTelemetry,
            usePerDeviceApis: usePerDeviceApis,
          ),
        ),
      ],
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 0.1,
                height: 1.1,
              ),
        ),
        const SizedBox(height: 2),
        DefaultTextStyle(
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.15,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          child: child,
        ),
      ],
    );
  }
}

class _FlowMetric extends ConsumerWidget {
  const _FlowMetric({
    required this.deviceId,
    this.homeTelemetry,
    this.usePerDeviceApis = true,
  });

  final String deviceId;
  final DashboardTelemetryDevice? homeTelemetry;
  final bool usePerDeviceApis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volumeUnit = ref.watch(volumeUnitProvider);

    Widget value;
    if (homeTelemetry != null) {
      value = _flowValue(
        context,
        valveOff: homeTelemetry!.valveIsOff,
        flowRateLpm: homeTelemetry!.flowRateLpm,
        status: homeTelemetry!.status,
        volumeUnit: volumeUnit,
      );
    } else if (!usePerDeviceApis) {
      value = const Text('Off');
    } else {
      final readingAsync = ref.watch(deviceCurrentReadingProvider(deviceId));
      final valveAsync = ref.watch(deviceValveProvider(deviceId));
      value = readingAsync.when(
        data: (reading) => _flowValue(
          context,
          valveOff: valveAsync.valueOrNull?.isOff ?? false,
          flowRateLpm: reading.flowRateLpm,
          status: reading.status.name,
          volumeUnit: volumeUnit,
        ),
        loading: () => const _MetricSkeleton(),
        error: (_, __) => const Text('—'),
      );
    }

    return _MetricCell(label: 'Flow', child: value);
  }

  Widget _flowValue(
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
    final rate = valveOff
        ? 'Off'
        : '${VolumeFormatter.fromLiters(flowRateLpm, volumeUnit).toStringAsFixed(1)} ${volumeUnit.symbol}/m';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FlowStatusIndicator(isFlowing: flowing, size: 12),
        const SizedBox(width: 4),
        Flexible(child: Text(rate)),
      ],
    );
  }
}

class _ReadingMetric extends ConsumerWidget {
  const _ReadingMetric({
    required this.deviceId,
    this.usePerDeviceApis = true,
  });

  final String deviceId;
  final bool usePerDeviceApis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volumeUnit = ref.watch(volumeUnitProvider);

    Widget format(double liters) => Text(
          VolumeFormatter.format(liters, volumeUnit, decimals: 1),
        );

    final patch = ref.watch(liveTelemetryPatchProvider(deviceId));
    final cumulative = patch?.cumulativeLiters;
    if (cumulative != null && cumulative > 0) {
      return _MetricCell(label: 'Meter', child: format(cumulative));
    }

    if (!usePerDeviceApis) {
      return const _MetricCell(label: 'Meter', child: Text('—'));
    }

    final readingAsync = ref.watch(deviceCurrentReadingProvider(deviceId));
    return readingAsync.when(
      data: (reading) =>
          _MetricCell(label: 'Meter', child: format(reading.cumulativeLiters)),
      loading: () => const _MetricCell(label: 'Meter', child: _MetricSkeleton()),
      error: (_, __) => const _MetricCell(label: 'Meter', child: Text('—')),
    );
  }
}

class _TodayMetric extends ConsumerWidget {
  const _TodayMetric({
    required this.deviceId,
    this.homeTelemetry,
    this.usePerDeviceApis = true,
  });

  final String deviceId;
  final DashboardTelemetryDevice? homeTelemetry;
  final bool usePerDeviceApis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volumeUnit = ref.watch(volumeUnitProvider);

    if (homeTelemetry != null) {
      return _MetricCell(
        label: 'Today',
        child: Text(
          VolumeFormatter.format(
            homeTelemetry!.todayLiters,
            volumeUnit,
            decimals: 0,
          ),
        ),
      );
    }

    if (!usePerDeviceApis) {
      return _MetricCell(
        label: 'Today',
        child: Text(VolumeFormatter.format(0, volumeUnit, decimals: 0)),
      );
    }

    final usageAsync = ref.watch(deviceTodayUsageProvider(deviceId));
    return usageAsync.when(
      data: (used) => _MetricCell(
        label: 'Today',
        child: Text(VolumeFormatter.format(used, volumeUnit, decimals: 0)),
      ),
      loading: () => const _MetricCell(label: 'Today', child: _MetricSkeleton()),
      error: (_, __) => const _MetricCell(label: 'Today', child: Text('—')),
    );
  }
}

class _MetricSkeleton extends StatelessWidget {
  const _MetricSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 12,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(3),
      ),
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
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (valveIsOff != null || !usePerDeviceApis) {
      final isOff = valveIsOff ?? true;
      return Transform.scale(
        scale: 0.78,
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
        scale: 0.78,
        child: Switch(
          value: !valve.isOff,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onChanged:
              isAdmin && !toggling && !maintenanceMode ? onChanged : null,
        ),
      ),
      loading: () => const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => const Icon(Icons.error_outline, size: 16),
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
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 20, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                'Add meter',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
