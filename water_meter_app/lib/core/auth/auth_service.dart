import '../models/user_profile.dart';

class AuthSignUpResult {
  const AuthSignUpResult({required this.requiresConfirmation});

  final bool requiresConfirmation;
}

abstract class AuthService {
  Future<void> initialize();
  Future<UserProfile?> getCurrentUser();
  Future<String?> getIdToken();
  Future<AuthSignUpResult> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
  });
  Future<void> confirmSignUp({
    required String email,
    required String code,
  });
  Future<void> resendSignUpCode({required String email});
  Future<UserProfile> signInWithPassword({
    required String email,
    required String password,
  });
  Future<UserProfile> signInWithGoogle();
  Future<void> signOut();
  Future<void> refreshProfile();
}
