import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exceptions.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/tenant_providers.dart';
import 'building_structure_fields.dart';

class TenantSetupScreen extends ConsumerStatefulWidget {
  const TenantSetupScreen({super.key});

  @override
  ConsumerState<TenantSetupScreen> createState() => _TenantSetupScreenState();
}

class _TenantSetupScreenState extends ConsumerState<TenantSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _structureDraft = BuildingStructureDraft();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(userProfileProvider).valueOrNull;
      if (profile != null && _nameController.text.isEmpty) {
        ref.read(tenantApiClientProvider).getTenant(profile.tenantId!).then(
          (config) {
            if (!mounted) return;
            setState(() => _nameController.text = config.name);
          },
          onError: (_) {},
        );
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _structureDraft.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final structureError = _structureDraft.validate();
    if (structureError != null) {
      setState(() => _error = structureError);
      return;
    }

    final profile = ref.read(userProfileProvider).valueOrNull;
    final tenantId = profile?.tenantId;
    if (tenantId == null) {
      setState(() => _error = 'No tenant found. Sign in again.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = ref.read(tenantApiClientProvider);
      await client.createBuilding(
        tenantId: tenantId,
        name: _nameController.text.trim(),
        structure: _structureDraft.toStructure(),
      );
      ref.invalidate(userProfileProvider);
      ref.invalidate(tenantConfigProvider);
      if (mounted) context.go('/');
    } on ApiException catch (e) {
      setState(() => _error = e.error.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set up building')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Configure your building',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Name your building and optionally define blocks, wings, and '
              'floors. This helps when adding water meters later.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
            ],
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Building name',
                      hintText: 'e.g. Sunrise Apartments',
                      prefixIcon: Icon(Icons.apartment),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 24),
                  BuildingStructureFields(
                    draft: _structureDraft,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save building'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
