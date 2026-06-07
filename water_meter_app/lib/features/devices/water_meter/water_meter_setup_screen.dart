import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/provisioning/provisioning_state.dart';
import '../../../core/providers/provisioning_providers.dart';
import 'steps/connect_hotspot_step.dart';
import 'steps/device_prep_step.dart';
import 'steps/enrollment_step.dart';
import 'steps/enrollment_success_step.dart';
import 'steps/home_wifi_step.dart';
import 'steps/name_device_step.dart';

class WaterMeterSetupScreen extends ConsumerWidget {
  const WaterMeterSetupScreen({super.key});

  static const _fullStepLabels = [
    'Prepare',
    'Connect',
    'WiFi',
    'Name',
    'Enroll',
    'Done',
  ];

  static const _mockStepLabels = ['Prepare', 'Name', 'Done'];

  List<String> get _stepLabels =>
      AppConfig.useMockProvisioning ? _mockStepLabels : _fullStepLabels;

  int _stepIndex(WaterMeterSetupStep step) {
    if (AppConfig.useMockProvisioning) {
      switch (step) {
        case WaterMeterSetupStep.devicePrep:
          return 0;
        case WaterMeterSetupStep.nameDevice:
          return 1;
        case WaterMeterSetupStep.success:
          return 2;
        default:
          return 1;
      }
    }

    switch (step) {
      case WaterMeterSetupStep.devicePrep:
        return 0;
      case WaterMeterSetupStep.connectHotspot:
        return 1;
      case WaterMeterSetupStep.homeWifi:
        return 2;
      case WaterMeterSetupStep.nameDevice:
        return 3;
      case WaterMeterSetupStep.enrollment:
        return 4;
      case WaterMeterSetupStep.success:
        return 5;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(provisioningNotifierProvider);
    final currentIndex = _stepIndex(state.step);
    final isLoading = state.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set up water meter'),
        leading: state.step == WaterMeterSetupStep.success || isLoading
            ? null
            : BackButton(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
              ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.step != WaterMeterSetupStep.success)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: List.generate(_stepLabels.length - 1, (index) {
                  final active = index <= currentIndex;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: index < _stepLabels.length - 2 ? 4 : 0,
                      ),
                      child: Column(
                        children: [
                          LinearProgressIndicator(
                            value: active ? 1 : 0,
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _stepLabels[index],
                            style: Theme.of(context).textTheme.labelSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          if (AppConfig.useMockProvisioning &&
              state.step != WaterMeterSetupStep.success)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: MaterialBanner(
                content: const Text(
                  'Mock provisioning: no hotspot or WiFi required.',
                ),
                leading: const Icon(Icons.science_outlined),
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .secondaryContainer
                    .withValues(alpha: 0.5),
                actions: const [SizedBox.shrink()],
              ),
            ),
          Expanded(
            child: switch (state.step) {
              WaterMeterSetupStep.devicePrep => DevicePrepStep(
                  onContinue: () {
                    final notifier =
                        ref.read(provisioningNotifierProvider.notifier);
                    if (AppConfig.useMockProvisioning) {
                      notifier.assignMockSerial();
                      notifier.goToStep(WaterMeterSetupStep.nameDevice);
                    } else {
                      notifier.goToStep(WaterMeterSetupStep.connectHotspot);
                    }
                  },
                ),
              WaterMeterSetupStep.connectHotspot =>
                const ConnectHotspotStep(),
              WaterMeterSetupStep.homeWifi => const HomeWifiStep(),
              WaterMeterSetupStep.nameDevice => const NameDeviceStep(),
              WaterMeterSetupStep.enrollment => const EnrollmentStep(),
              WaterMeterSetupStep.success =>
                const EnrollmentSuccessStep(),
            },
          ),
        ],
      ),
    );
  }
}
