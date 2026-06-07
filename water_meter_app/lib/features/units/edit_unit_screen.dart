import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/audit_event.dart';
import '../../core/models/water_unit.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/control_providers.dart';
import '../../core/providers/unit_providers.dart';
import '../../core/services/audit_logger.dart';

class EditUnitScreen extends ConsumerStatefulWidget {
  const EditUnitScreen({super.key, required this.unitId});

  final String unitId;

  @override
  ConsumerState<EditUnitScreen> createState() => _EditUnitScreenState();
}

class _EditUnitScreenState extends ConsumerState<EditUnitScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _flatController;
  late final TextEditingController _floorController;
  late final TextEditingController _wingController;
  late final TextEditingController _blockController;
  late final TextEditingController _residentController;
  late final TextEditingController _notesController;
  bool _maintenanceMode = false;
  bool _saving = false;
  WaterUnit? _unit;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _flatController = TextEditingController();
    _floorController = TextEditingController();
    _wingController = TextEditingController();
    _blockController = TextEditingController();
    _residentController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _flatController.dispose();
    _floorController.dispose();
    _wingController.dispose();
    _blockController.dispose();
    _residentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _populateForm(WaterUnit unit) {
    if (_unit?.id == unit.id) return;
    _unit = unit;
    _nameController.text = unit.name;
    _flatController.text = unit.flatNumber;
    _floorController.text = unit.floor;
    _wingController.text = unit.wing;
    _blockController.text = unit.block;
    _residentController.text = unit.residentName ?? '';
    _notesController.text = unit.notes ?? '';
    _maintenanceMode = unit.maintenanceMode;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _unit == null) return;

    setState(() => _saving = true);
    try {
      final updated = _unit!.copyWith(
        name: _nameController.text.trim(),
        flatNumber: _flatController.text.trim(),
        floor: _floorController.text.trim(),
        wing: _wingController.text.trim(),
        block: _blockController.text.trim(),
        residentName: _residentController.text.trim().isEmpty
            ? null
            : _residentController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        maintenanceMode: _maintenanceMode,
        clearResidentName: _residentController.text.trim().isEmpty,
        clearNotes: _notesController.text.trim().isEmpty,
      );

      final prefs = await ref.read(preferencesStorageProvider.future);
      await prefs.updateWaterUnit(updated);
      ref.invalidate(waterUnitsProvider);

      final profile = await ref.read(userProfileProvider.future);
      await ref.read(auditLoggerProvider).log(
            actorEmail: profile?.email ?? 'unknown',
            action: _maintenanceMode != _unit!.maintenanceMode
                ? AuditAction.maintenanceMode
                : AuditAction.unitEdit,
            unitId: updated.id,
            unitName: updated.name,
            details: _maintenanceMode != _unit!.maintenanceMode
                ? (_maintenanceMode ? 'Enabled' : 'Disabled')
                : 'Metadata updated',
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unit saved')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isDeviceAdminProvider);
    final unitsAsync = ref.watch(waterUnitsProvider);

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit unit')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text('Only admins can edit unit metadata.'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit unit'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: unitsAsync.when(
        data: (units) {
          WaterUnit? unit;
          for (final u in units) {
            if (u.id == widget.unitId) {
              unit = u;
              break;
            }
          }
          if (unit == null) {
            return const Center(child: Text('Unit not found'));
          }
          _populateForm(unit);

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unit details',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          unit.deviceId,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _flatController,
                          decoration: const InputDecoration(
                            labelText: 'Flat number',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _floorController,
                                decoration: const InputDecoration(
                                  labelText: 'Floor',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _wingController,
                                decoration: const InputDecoration(
                                  labelText: 'Wing',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _blockController,
                          decoration: const InputDecoration(
                            labelText: 'Block',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _residentController,
                          decoration: const InputDecoration(
                            labelText: 'Resident name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notesController,
                          decoration: const InputDecoration(
                            labelText: 'Notes',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: SwitchListTile(
                    title: const Text('Maintenance mode'),
                    subtitle: const Text(
                      'Suppress alerts and exclude from automated policies',
                    ),
                    value: _maintenanceMode,
                    onChanged: (v) => setState(() => _maintenanceMode = v),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Save changes'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
