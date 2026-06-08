import '../models/tenant_config.dart';
import '../models/user_profile.dart';
import '../storage/preferences_storage.dart';
import '../storage/session_storage.dart';
import 'auth_service.dart';

/// In-memory + secure-storage auth for local development without AWS.
class MockAuthService implements AuthService {
  MockAuthService({SessionStorage? storage, PreferencesStorage? prefs})
      : _storage = storage ?? SessionStorage(),
        _prefs = prefs;

  final SessionStorage _storage;
  final PreferencesStorage? _prefs;
  UserProfile? _cached;

  static const mockAdminInviteCode = 'ADMIN-DEMO';

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

  Future<bool> tenantExists(PreferencesStorage prefs) => Future.value(prefs.tenantExists);

  Future<UserProfile> createTenant({
    required String name,
    required TenantStructure structure,
    required PreferencesStorage prefs,
  }) async {
    if (prefs.tenantExists) {
      throw TenantSetupException('Tenant already exists');
    }
    var user = (await getCurrentUser())!;
    final tenantId = 'tenant-${user.userId.substring(0, 8)}';
    await prefs.setTenantConfig(
      TenantConfig(tenantId: tenantId, name: name, structure: structure),
    );
    await prefs.setAdminInviteCode(mockAdminInviteCode);
    user = user.copyWith(
      tenantId: tenantId,
      onboardingComplete: true,
      isTenantOwner: true,
    );
    _cached = user;
    await _storage.saveProfile(user);
    return user;
  }

  Future<UserProfile> joinAsAdmin({
    required String inviteCode,
    required PreferencesStorage prefs,
  }) async {
    final config = prefs.getTenantConfig();
    if (config == null) {
      throw TenantJoinException('No tenant configured');
    }
    final expected = prefs.getAdminInviteCode() ?? mockAdminInviteCode;
    if (inviteCode.trim().toUpperCase() != expected.toUpperCase()) {
      throw TenantJoinException('Invalid admin invite code');
    }
    var user = (await getCurrentUser())!;
    user = user.copyWith(
      tenantId: config.tenantId,
      onboardingComplete: true,
      isTenantOwner: false,
    );
    _cached = user;
    await _storage.saveProfile(user);
    return user;
  }

  Future<String> generateAdminInvite(PreferencesStorage prefs) async {
    final code = 'ADMIN-${DateTime.now().millisecondsSinceEpoch % 100000}';
    await prefs.setAdminInviteCode(code);
    return code;
  }
}

class TenantJoinException implements Exception {
  TenantJoinException(this.message);
  final String message;

  @override
  String toString() => message;
}

class TenantSetupException implements Exception {
  TenantSetupException(this.message);
  final String message;

  @override
  String toString() => message;
}
