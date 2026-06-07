import '../models/user_profile.dart';
import '../storage/session_storage.dart';
import 'auth_service.dart';

/// In-memory + secure-storage auth for local development without AWS.
class MockAuthService implements AuthService {
  MockAuthService({SessionStorage? storage})
      : _storage = storage ?? SessionStorage();

  final SessionStorage _storage;
  UserProfile? _cached;

  static const mockInviteCode = 'DEMO-1234';

  @override
  Future<void> initialize() async {
    _cached = await _storage.readProfile();
  }

  @override
  Future<UserProfile?> getCurrentUser() async {
    _cached ??= await _storage.readProfile();
    return _cached;
  }

  @override
  Future<String?> getIdToken() async {
    final user = await getCurrentUser();
    return user?.idToken ?? 'mock-id-token';
  }

  @override
  Future<UserProfile> signInWithGoogle() async {
    final profile = UserProfile(
      userId: 'mock-user-${DateTime.now().millisecondsSinceEpoch}',
      email: 'demo.user@gmail.com',
      displayName: 'Demo User',
      idToken: 'mock-id-token-${DateTime.now().millisecondsSinceEpoch}',
    );
    _cached = profile;
    await _storage.saveProfile(profile);
    return profile;
  }

  @override
  Future<void> signOut() async {
    _cached = null;
    await _storage.clear();
  }

  @override
  Future<void> refreshProfile() async {
    _cached = await _storage.readProfile();
  }

  Future<UserProfile> setRole(UserRole role) async {
    var user = (await getCurrentUser())!;
    user = user.copyWith(role: role);
    _cached = user;
    await _storage.saveProfile(user);
    return user;
  }

  Future<UserProfile> createTenant() async {
    var user = (await getCurrentUser())!;
    final tenantId = 'tenant-${user.userId.substring(0, 8)}';
    user = user.copyWith(
      tenantId: tenantId,
      inviteCode: mockInviteCode,
      onboardingComplete: true,
    );
    _cached = user;
    await _storage.saveProfile(user);
    return user;
  }

  Future<UserProfile> joinTenant(String inviteCode) async {
    if (inviteCode.trim().toUpperCase() != mockInviteCode) {
      throw TenantJoinException('Invalid invite code');
    }
    var user = (await getCurrentUser())!;
    user = user.copyWith(
      tenantId: 'tenant-shared-demo',
      onboardingComplete: true,
    );
    _cached = user;
    await _storage.saveProfile(user);
    return user;
  }
}

class TenantJoinException implements Exception {
  TenantJoinException(this.message);
  final String message;

  @override
  String toString() => message;
}
