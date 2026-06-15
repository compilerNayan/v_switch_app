import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class DummyDevicesCountScreen extends StatefulWidget {
  const DummyDevicesCountScreen({super.key});

  @override
  State<DummyDevicesCountScreen> createState() => _DummyDevicesCountScreenState();
}

class _DummyDevicesCountScreenState extends State<DummyDevicesCountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _countController = TextEditingController(text: '25');

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;
    final count = int.parse(_countController.text.trim());
    context.go('/onboarding/dummy-devices/provision', extra: count);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dummy devices')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'How many dummy devices?',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'We will create a demo building with blocks, wings, and floors, '
                  'then enroll meters with random resident details.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _countController,
                  decoration: const InputDecoration(
                    labelText: 'Number of devices',
                    hintText: '1 to 1000',
                    prefixIcon: Icon(Icons.sensors),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a number';
                    }
                    final parsed = int.tryParse(value.trim());
                    if (parsed == null || parsed < 1 || parsed > 1000) {
                      return 'Enter a number between 1 and 1000';
                    }
                    return null;
                  },
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _continue,
                  child: const Text('Create demo building'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/onboarding/dummy-devices'),
                  child: const Text('Back'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
