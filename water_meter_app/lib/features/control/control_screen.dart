import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/quota_config.dart';
import '../../core/models/valve_state.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/control_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/units.dart';
import '../../shared/widgets/device_scaffold_actions.dart';

class ControlScreen extends ConsumerStatefulWidget {
  const ControlScreen({super.key});

  @override
  ConsumerState<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends ConsumerState<ControlScreen> {
  double? _sliderValue;
  bool _savingQuota = false;

  @override
  Widget build(BuildContext context) {
    final valveAsync = ref.watch(valveControlNotifierProvider);
    final quotaAsync = ref.watch(quotaStateProvider);
    final isAdmin = ref.watch(isDeviceAdminProvider);
    final volumeUnit = ref.watch(volumeUnitProvider);

    final quotaData = quotaAsync.valueOrNull;
    if (quotaData != null && ref.read(quotaConfigNotifierProvider) == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(quotaConfigNotifierProvider) == null) {
          ref.read(quotaConfigNotifierProvider.notifier).loadFrom(quotaData);
        }
      });
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(valveControlNotifierProvider);
          ref.invalidate(quotaStateProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 120,
              pinned: true,
              leading: const DeviceBackButton(),
              flexibleSpace: FlexibleSpaceBar(
                title: const DeviceScreenTitle(fallback: 'Control'),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.dashboardHeaderGradient(
                      Theme.of(context).colorScheme,
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  valveAsync.when(
                    data: (valve) => _TapControlCard(
                      valve: valve,
                      isAdmin: isAdmin,
                      sliderValue: _sliderValue ?? valve.targetPressurePercent,
                      onSliderChanged: isAdmin
                          ? (value) => setState(() => _sliderValue = value)
                          : null,
                      onSliderCommitted: isAdmin
                          ? (value) {
                              setState(() => _sliderValue = value);
                              ref
                                  .read(valveControlNotifierProvider.notifier)
                                  .setPressure(value);
                            }
                          : null,
                      onTogglePower: isAdmin
                          ? () => ref
                              .read(valveControlNotifierProvider.notifier)
                              .togglePower()
                          : null,
                    ),
                    loading: () => const _LoadingCard(height: 220),
                    error: (e, _) => _ErrorCard(message: e.toString()),
                  ),
                  const SizedBox(height: 12),
                  quotaAsync.when(
                    data: (quota) => _QuotaSummaryCard(
                      quota: quota,
                      unit: volumeUnit,
                    ),
                    loading: () => const _LoadingCard(height: 140),
                    error: (e, _) => _ErrorCard(message: e.toString()),
                  ),
                  const SizedBox(height: 12),
                  if (isAdmin)
                    quotaAsync.when(
                      data: (_) => _QuotaConfigSection(
                        saving: _savingQuota,
                        onSave: () => _saveQuota(context),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    )
                  else
                    const _ReadonlyQuotaHint(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveQuota(BuildContext context) async {
    setState(() => _savingQuota = true);
    try {
      await ref.read(quotaConfigNotifierProvider.notifier).save();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quota settings saved')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingQuota = false);
    }
  }
}

class _TapControlCard extends StatelessWidget {
  const _TapControlCard({
    required this.valve,
    required this.isAdmin,
    required this.sliderValue,
    this.onSliderChanged,
    this.onSliderCommitted,
    this.onTogglePower,
  });

  final ValveState valve;
  final bool isAdmin;
  final double sliderValue;
  final ValueChanged<double>? onSliderChanged;
  final ValueChanged<double>? onSliderCommitted;
  final VoidCallback? onTogglePower;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isOn = !valve.isOff;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Tap control', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (valve.controlMode == ValveControlMode.quota)
                  Chip(
                    label: Text(
                      'Quota limited to ${valve.quotaCapPercent?.toStringAsFixed(0)}%',
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _PowerButton(
                  isOn: isOn,
                  enabled: isAdmin && onTogglePower != null,
                  onPressed: onTogglePower,
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Actual: ${valve.actualPressurePercent.toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'Target: ${valve.targetPressurePercent.toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (valve.isOff)
                        Text(
                          'Tap is off — maintenance mode',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.error,
                              ),
                        )
                      else if (valve.controlMode == ValveControlMode.quota)
                        Text(
                          'Effective: ${valve.effectivePressurePercent.toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Slider(
              value: sliderValue.clamp(0, 100),
              min: 0,
              max: 100,
              divisions: 20,
              label: '${sliderValue.round()}%',
              onChanged: onSliderChanged,
              onChangeEnd: onSliderCommitted,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0%', style: Theme.of(context).textTheme.bodySmall),
                Text(
                  '${sliderValue.round()}%',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Text('100%', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            if (!isAdmin)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Read-only access — controls are disabled',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.outline,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PowerButton extends StatelessWidget {
  const _PowerButton({
    required this.isOn,
    required this.enabled,
    this.onPressed,
  });

  final bool isOn;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = isOn ? Colors.green.shade600 : scheme.outline;

    return Material(
      color: color.withValues(alpha: 0.15),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onPressed : null,
        child: SizedBox(
          width: 88,
          height: 88,
          child: Icon(
            isOn ? Icons.water_drop : Icons.water_drop_outlined,
            size: 40,
            color: enabled ? color : scheme.outline.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

class _QuotaSummaryCard extends StatelessWidget {
  const _QuotaSummaryCard({
    required this.quota,
    required this.unit,
  });

  final QuotaResponse quota;
  final VolumeUnit unit;

  @override
  Widget build(BuildContext context) {
    if (!quota.enabled) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Today's quota", style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Daily quota is disabled',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    final status = quota.status;
    final progress = quota.dailyLimitLiters == 0
        ? 0.0
        : (status.usedLiters / quota.dailyLimitLiters).clamp(0.0, 1.0).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Today's quota", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${VolumeFormatter.format(status.usedLiters, unit, decimals: 0)} of '
              '${VolumeFormatter.format(quota.dailyLimitLiters, unit, decimals: 0)} used',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (status.nextStepAtLiters != null)
              Text(
                'Next step at ${VolumeFormatter.format(status.nextStepAtLiters!, unit, decimals: 0)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < quota.steps.length; i++)
                  _QuotaStepChip(
                    step: quota.steps[i],
                    triggered: i <= status.activeStepIndex,
                    unit: unit,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuotaStepChip extends StatelessWidget {
  const _QuotaStepChip({
    required this.step,
    required this.triggered,
    required this.unit,
  });

  final QuotaStep step;
  final bool triggered;
  final VolumeUnit unit;

  @override
  Widget build(BuildContext context) {
    final label = switch (step.action) {
      QuotaStepAction.reducePressure =>
        '${VolumeFormatter.format(step.atLitersUsed, unit, decimals: 0)} → -${step.value?.toStringAsFixed(0)}%',
      QuotaStepAction.turnOff =>
        '${VolumeFormatter.format(step.atLitersUsed, unit, decimals: 0)} → Off',
    };

    return Chip(
      avatar: Icon(
        triggered ? Icons.check_circle : Icons.radio_button_unchecked,
        size: 18,
        color: triggered ? Colors.green : null,
      ),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _QuotaConfigSection extends ConsumerWidget {
  const _QuotaConfigSection({
    required this.saving,
    required this.onSave,
  });

  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(quotaConfigNotifierProvider);
    if (draft == null) {
      return const _LoadingCard(height: 120);
    }

    final limitController = TextEditingController(
      text: draft.dailyLimitLiters.toStringAsFixed(0),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quota settings', style: Theme.of(context).textTheme.titleMedium),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable daily quota'),
              value: draft.enabled,
              onChanged: (value) =>
                  ref.read(quotaConfigNotifierProvider.notifier).setEnabled(value),
            ),
            TextField(
              controller: limitController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Daily limit (liters)',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                final parsed = double.tryParse(value);
                if (parsed != null && parsed > 0) {
                  ref
                      .read(quotaConfigNotifierProvider.notifier)
                      .setDailyLimit(parsed);
                }
              },
            ),
            const SizedBox(height: 16),
            Text('Steps', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (var i = 0; i < draft.steps.length; i++)
              _QuotaStepEditor(
                index: i,
                step: draft.steps[i],
                onChanged: (step) => ref
                    .read(quotaConfigNotifierProvider.notifier)
                    .updateStep(i, step),
                onRemove: draft.steps.length > 1
                    ? () => ref
                        .read(quotaConfigNotifierProvider.notifier)
                        .removeStep(i)
                    : null,
              ),
            TextButton.icon(
              onPressed: () =>
                  ref.read(quotaConfigNotifierProvider.notifier).addStep(),
              icon: const Icon(Icons.add),
              label: const Text('Add step'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: saving ? null : onSave,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Save quota settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuotaStepEditor extends StatelessWidget {
  const _QuotaStepEditor({
    required this.index,
    required this.step,
    required this.onChanged,
    this.onRemove,
  });

  final int index;
  final QuotaStep step;
  final ValueChanged<QuotaStep> onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final thresholdController = TextEditingController(
      text: step.atLitersUsed.toStringAsFixed(0),
    );
    final valueController = TextEditingController(
      text: step.value?.toStringAsFixed(0) ?? '',
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                TextField(
                  controller: thresholdController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Step ${index + 1} at (L)',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    final parsed = double.tryParse(value);
                    if (parsed != null) {
                      onChanged(step.copyWith(atLitersUsed: parsed));
                    }
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<QuotaStepAction>(
                  initialValue: step.action,
                  decoration: const InputDecoration(
                    labelText: 'Action',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: QuotaStepAction.values
                      .map(
                        (action) => DropdownMenuItem(
                          value: action,
                          child: Text(action.label),
                        ),
                      )
                      .toList(),
                  onChanged: (action) {
                    if (action == null) return;
                    onChanged(
                      step.copyWith(
                        action: action,
                        clearValue: action == QuotaStepAction.turnOff,
                      ),
                    );
                  },
                ),
                if (step.action == QuotaStepAction.reducePressure) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: valueController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Reduce by (%)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      final parsed = double.tryParse(value);
                      if (parsed != null) {
                        onChanged(step.copyWith(value: parsed));
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Remove step',
            ),
        ],
      ),
    );
  }
}

class _ReadonlyQuotaHint extends StatelessWidget {
  const _ReadonlyQuotaHint();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Theme.of(context).colorScheme.outline),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Ask an admin to change quota settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: height,
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
