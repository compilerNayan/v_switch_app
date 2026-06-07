import '../models/user_profile.dart';

abstract class AuthService {
  Future<void> initialize();
  Future<UserProfile?> getCurrentUser();
  Future<String?> getIdToken();
  Future<UserProfile> signInWithGoogle();
  Future<void> signOut();
  Future<void> refreshProfile();
}
