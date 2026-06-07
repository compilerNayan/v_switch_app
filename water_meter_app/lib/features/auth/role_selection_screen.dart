import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exceptions.dart';
import '../../core/models/user_profile.dart';
import '../../core/providers/app_providers.dart';

class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() =>
      _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  bool _isLoading = false;
  String? _error;

  Future<void> _selectRole(UserRole role) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final client = ref.read(tenantApiClientProvider);
      final profile = await client.setRole(role);
      ref.invalidate(userProfileProvider);

      if (!mounted) return;
      if (role == UserRole.readonly && !profile.onboardingComplete) {
        context.go('/onboarding/join');
      } else {
        context.go('/');
      }
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
      appBar: AppBar(title: const Text('Choose your role')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'How will you use this app?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Admins create an organization and manage devices. Read-only users join with an invite code.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            _RoleCard(
              icon: Icons.admin_panel_settings,
              title: 'Admin',
              description:
                  'Create and manage your organization, devices, and users.',
              onTap: _isLoading ? null : () => _selectRole(UserRole.admin),
            ),
            const SizedBox(height: 12),
            _RoleCard(
              icon: Icons.visibility,
              title: 'Resident',
              description:
                  'View your unit water usage using a building or unit invite code.',
              onTap: _isLoading ? null : () => _selectRole(UserRole.readonly),
            ),
            const SizedBox(height: 12),
            _RoleCard(
              icon: Icons.build,
              title: 'Maintenance',
              description:
                  'View all units and control assigned meters for repairs.',
              onTap: _isLoading ? null : () => _selectRole(UserRole.maintenance),
            ),
            if (_isLoading) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(description, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
