import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exceptions.dart';
import '../../core/auth/pending_registration.dart';
import '../../core/config/app_config.dart';
import '../../core/providers/app_providers.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _signInFormKey = GlobalKey<FormState>();
  final _signUpFormKey = GlobalKey<FormState>();

  final _signInEmailController = TextEditingController();
  final _signInPasswordController = TextEditingController();

  final _signUpEmailController = TextEditingController();
  final _signUpPasswordController = TextEditingController();
  final _signUpConfirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _selectedGender;

  static const _genderOptions = {
    'male': 'Male',
    'female': 'Female',
    'other': 'Other',
  };

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _signInEmailController.dispose();
    _signInPasswordController.dispose();
    _signUpEmailController.dispose();
    _signUpPasswordController.dispose();
    _signUpConfirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_signInFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = ref.read(authServiceProvider);
      await auth.signInWithPassword(
        email: _signInEmailController.text.trim(),
        password: _signInPasswordController.text,
      );

      if (!AppConfig.useMockAuth) {
        final api = ref.read(tenantApiClientProvider);
        try {
          final profile = await api.getMe();
          ref.invalidate(userProfileProvider);
          if (!mounted) return;
          if (profile.needsOnboarding) {
            context.go('/onboarding/admin-invite');
          } else {
            context.go('/');
          }
          return;
        } on ApiException catch (e) {
          if (e.statusCode == 404) {
            await auth.signOut();
            setState(() =>
                _error = 'Account not registered. Please sign up first.');
            return;
          }
          rethrow;
        }
      }

      ref.invalidate(userProfileProvider);

      if (!mounted) return;
      final profile = await ref.read(userProfileProvider.future);
      if (profile == null) {
        setState(() => _error = 'Sign-in failed');
        return;
      }
      if (profile.needsOnboarding) {
        context.go('/onboarding/admin-invite');
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

  Future<void> _signUp() async {
    if (!_signUpFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final email = _signUpEmailController.text.trim();
      final password = _signUpPasswordController.text;
      final auth = ref.read(authServiceProvider);

      final result = await auth.signUp(
        email: email,
        password: password,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phone: _phoneController.text.trim(),
        gender: _selectedGender!,
      );

      ref.read(pendingRegistrationProvider.notifier).state = PendingRegistration(
        email: email,
        password: password,
        phone: _phoneController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );

      if (!mounted) return;
      if (result.requiresConfirmation) {
        context.go('/auth/confirm');
      } else {
        await _completeRegistration();
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _completeRegistration() async {
    final pending = ref.read(pendingRegistrationProvider);
    if (pending == null) {
      setState(() => _error = 'Registration details missing');
      return;
    }

    final auth = ref.read(authServiceProvider);
    await auth.signInWithPassword(
      email: pending.email,
      password: pending.password,
    );

    final api = ref.read(tenantApiClientProvider);
    await api.registerUser(
      email: pending.email,
      phone: pending.phone,
      firstName: pending.firstName,
      lastName: pending.lastName,
    );

    ref.read(pendingRegistrationProvider.notifier).state = null;
    ref.invalidate(userProfileProvider);

    if (mounted) context.go('/onboarding/building-setup');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.water_drop, size: 72, color: scheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    AppConfig.appName,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to view and manage your water usage.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'Sign in'),
                      Tab(text: 'Sign up'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: TextStyle(color: scheme.error),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    height: 480,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildSignInForm(scheme),
                        _buildSignUpForm(scheme),
                      ],
                    ),
                  ),
                  if (AppConfig.useMockAuth) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Mock auth: use confirmation code 123456 after sign up',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignInForm(ColorScheme scheme) {
    return Form(
      key: _signInFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _signInEmailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _signInPasswordController,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isLoading ? null : _signIn,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Sign in'),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpForm(ColorScheme scheme) {
    return Form(
      key: _signUpFormKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _signUpEmailController,
              decoration: const InputDecoration(
                labelText: 'Email address',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Email is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: const InputDecoration(
                labelText: 'Gender',
                border: OutlineInputBorder(),
              ),
              items: _genderOptions.entries
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value),
                    ),
                  )
                  .toList(),
              onChanged: _isLoading
                  ? null
                  : (value) => setState(() => _selectedGender = value),
              validator: (value) =>
                  value == null || value.isEmpty ? 'Gender is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                border: OutlineInputBorder(),
                hintText: '+919876543210',
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Phone is required (E.164 format, e.g. +91...)';
                }
                if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(value.trim())) {
                  return 'Use E.164 format, e.g. +919876543210';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _firstNameController,
              decoration: const InputDecoration(
                labelText: 'Given name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lastNameController,
              decoration: const InputDecoration(
                labelText: 'Family name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _signUpPasswordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (value) {
                if (value == null || value.length < 8) {
                  return 'Password must be at least 8 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _signUpConfirmPasswordController,
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (value) {
                if (value != _signUpPasswordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading ? null : _signUp,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create account'),
            ),
          ],
        ),
      ),
    );
  }
}
