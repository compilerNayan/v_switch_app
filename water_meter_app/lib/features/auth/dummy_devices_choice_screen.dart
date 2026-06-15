import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DummyDevicesChoiceScreen extends StatelessWidget {
  const DummyDevicesChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Demo devices')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add dummy water meters?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                'You can preload demo meters with sample usage data for testing, '
                'or continue and add real devices later from the dashboard.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => context.go('/onboarding/dummy-devices/count'),
                child: const Text('Yes, add dummy devices'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go('/onboarding/building-setup'),
                child: const Text('No, set up building manually'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
