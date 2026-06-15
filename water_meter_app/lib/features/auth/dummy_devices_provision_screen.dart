import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exceptions.dart';
import '../../core/dummy/dummy_onboarding_service.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/tenant_providers.dart';
import '../../core/providers/unit_providers.dart';

class DummyDevicesProvisionScreen extends ConsumerStatefulWidget {
  const DummyDevicesProvisionScreen({super.key, required this.deviceCount});

  final int deviceCount;

  @override
  ConsumerState<DummyDevicesProvisionScreen> createState() =>
      _DummyDevicesProvisionScreenState();
}

class _DummyDevicesProvisionScreenState
    extends ConsumerState<DummyDevicesProvisionScreen> {
  static const _service = DummyOnboardingService();

  String _status = 'Preparing demo building...';
  String? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _provision());
    }
  }

  Future<void> _provision() async {
    final profile = ref.read(userProfileProvider).valueOrNull;
    final tenantId = profile?.tenantId;
    if (profile == null || tenantId == null) {
      setState(() => _error = 'No tenant found. Sign in again.');
      return;
    }

    final api = ref.read(tenantApiClientProvider);

    try {
      setState(() {
        _error = null;
        _status = 'Creating building structure...';
      });

      final response = await _service.provisionDummyDevices(
        apiClient: api,
        tenantId: tenantId,
        profile: profile,
        deviceCount: widget.deviceCount,
      );

      if (!mounted) return;

      if (response.failed > 0) {
        setState(() {
          _error =
              'Enrolled ${response.enrolled} of ${response.requested} devices. '
              '${response.failed} failed.';
        });
        return;
      }

      setState(() => _status = 'Enrolled ${response.enrolled} dummy devices.');
      ref.invalidate(userProfileProvider);
      ref.invalidate(tenantConfigProvider);
      ref.invalidate(waterUnitsProvider);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (mounted) context.go('/');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.error.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Setting up demo')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Creating ${widget.deviceCount} dummy devices',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              if (_error == null) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 24),
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ] else ...[
                Icon(Icons.error_outline, color: scheme.error, size: 48),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.error),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _provision,
                  child: const Text('Retry'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/onboarding/dummy-devices/count'),
                  child: const Text('Back'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
