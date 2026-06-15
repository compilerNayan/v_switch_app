import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exceptions.dart';
import '../../core/auth/auth_error_message.dart';
import '../../core/config/app_config.dart';
import '../../core/providers/app_providers.dart';
import 'registration_flow.dart';

class ConfirmSignUpScreen extends ConsumerStatefulWidget {
  const ConfirmSignUpScreen({super.key});

  @override
  ConsumerState<ConfirmSignUpScreen> createState() =>
      _ConfirmSignUpScreenState();
}

class _ConfirmSignUpScreenState extends ConsumerState<ConfirmSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  bool _isLoading = false;
  bool _emailVerified = false;
  bool _restoringPending = true;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restorePending());
  }

  Future<void> _restorePending() async {
    await loadPendingRegistration(ref);
    if (mounted) setState(() => _restoringPending = false);
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (!_formKey.currentState!.validate()) return;

    final pending = ref.read(pendingRegistrationProvider);
    if (pending == null) {
      setState(() => _error = 'Sign-up session expired. Please sign up again.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _info = null;
    });

    final auth = ref.read(authServiceProvider);
    final api = ref.read(tenantApiClientProvider);

    try {
      if (!_emailVerified) {
        await auth.confirmSignUp(
          email: pending.email,
          code: _codeController.text.trim(),
        );
        _emailVerified = true;
        debugPrint('[auth] Email verified for ${pending.email}');
      }

      final token = await auth.getIdToken();
      if (token == null) {
        await auth.signInWithPassword(
          email: pending.email,
          password: pending.password,
        );
        debugPrint('[auth] Signed in after verification');
      }

      await api.registerUser(
        email: pending.email,
        phone: pending.phone,
        firstName: pending.firstName,
        lastName: pending.lastName,
      );
      debugPrint('[auth] Backend registration complete');

      await clearPendingRegistration(ref);
      ref.invalidate(userProfileProvider);

      if (mounted) context.go('/onboarding/dummy-devices');
    } on ApiException catch (e) {
      debugPrint('[auth] registerUser failed: ${e.statusCode} ${e.error.message}');
      setState(() {
        _emailVerified = true;
        _error = 'Account setup failed: ${e.error.message}';
      });
    } catch (e) {
      debugPrint('[auth] verification flow failed: $e');
      setState(() {
        _error = _emailVerified
            ? 'Account setup failed: ${formatAuthError(e)}'
            : 'Email verification failed: ${formatAuthError(e)}';
        if (!_emailVerified) {
          _emailVerified = false;
        }
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    final pending = ref.read(pendingRegistrationProvider);
    if (pending == null) {
      setState(() => _error = 'Sign-up session expired. Please sign up again.');
      return;
    }

    setState(() {
      _error = null;
      _info = null;
      _emailVerified = false;
    });

    try {
      final auth = ref.read(authServiceProvider);
      await auth.resendSignUpCode(email: pending.email);
      setState(() => _info = 'Verification code sent');
    } catch (e) {
      setState(() => _error = formatAuthError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingRegistrationProvider);
    final scheme = Theme.of(context).colorScheme;

    if (_restoringPending) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (pending == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Verify email')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Sign-up session expired.'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go('/auth'),
                  child: const Text('Back to sign up'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Verify email')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _emailVerified
                          ? 'Email verified. Finish creating your account.'
                          : 'Enter the verification code sent to ${pending.email}',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: TextStyle(color: scheme.error),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_info != null) ...[
                      Text(
                        _info!,
                        style: TextStyle(color: scheme.primary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (!_emailVerified) ...[
                      TextFormField(
                        controller: _codeController,
                        decoration: const InputDecoration(
                          labelText: 'Verification code',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Code is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                    FilledButton(
                      onPressed: _isLoading ? null : _confirm,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _emailVerified
                                  ? 'Retry account setup'
                                  : 'Verify and continue',
                            ),
                    ),
                    if (!_emailVerified) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _isLoading ? null : _resendCode,
                        child: const Text('Resend code'),
                      ),
                    ],
                    if (AppConfig.useMockAuth) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Mock auth: use code 123456',
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
      ),
    );
  }
}
