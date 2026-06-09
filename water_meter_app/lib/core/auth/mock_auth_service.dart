import '../models/tenant_config.dart';
import '../models/user_profile.dart';
import '../storage/preferences_storage.dart';
import '../storage/session_storage.dart';
import '../utils/tenant_id.dart';
import 'auth_service.dart';

/// In-memory + secure-storage auth for local development without AWS.
class MockAuthService implements AuthService {
  MockAuthService({SessionStorage? storage, PreferencesStorage? prefs})
      : _storage = storage ?? SessionStorage(),
        _prefs = prefs;

  final SessionStorage _storage;
  final PreferencesStorage? _prefs;
  UserProfile? _cached;
  String? _pendingEmail;
  String? _pendingPassword;
  String? _pendingFirstName;
  String? _pendingLastName;
  String? _pendingPhone;

  static const mockAdminInviteCode = 'ADMIN-DEMO';
  static const mockConfirmCode = '123456';

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
  Future<AuthSignUpResult> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    required String gender,
  }) async {
    _pendingEmail = email.trim();
    _pendingPassword = password;
    _pendingFirstName = firstName.trim();
    _pendingLastName = lastName.trim();
    _pendingPhone = phone.trim();
    return const AuthSignUpResult(requiresConfirmation: true);
  }

  @override
  Future<void> confirmSignUp({
    required String email,
    required String code,
  }) async {
    if (code.trim() != mockConfirmCode) {
      throw Exception('Invalid confirmation code');
    }
    if (_pendingEmail == null || _pendingEmail != email.trim()) {
      throw Exception('No pending sign-up for this email');
    }
  }

  @override
  Future<void> resendSignUpCode({required String email}) async {
    if (_pendingEmail != email.trim()) {
      throw Exception('No pending sign-up for this email');
    }
  }

  @override
  Future<UserProfile> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final existing = await getCurrentUser();
    if (existing != null &&
        existing.email == email.trim() &&
        existing.idToken != null) {
      return existing;
    }

    if (_pendingEmail == email.trim() && _pendingPassword == password) {
      final profile = UserProfile(
        userId: 'mock-user-${email.hashCode.abs()}',
        email: email.trim(),
        displayName: '$_pendingFirstName $_pendingLastName'.trim(),
        firstName: _pendingFirstName,
        lastName: _pendingLastName,
        phone: _pendingPhone,
        idToken: 'mock-id-token-${DateTime.now().millisecondsSinceEpoch}',
      );
      _cached = profile;
      await _storage.saveProfile(profile);
      return profile;
    }

    if (existing != null && existing.email == email.trim()) {
      return existing;
    }

    throw Exception('Invalid email or password');
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
    _pendingEmail = null;
    _pendingPassword = null;
    await _storage.clear();
  }

  @override
  Future<void> refreshProfile() async {
    _cached = await _storage.readProfile();
  }

  Future<UserProfile> registerUser({
    required String email,
    required String phone,
    required String firstName,
    required String lastName,
    required PreferencesStorage prefs,
  }) async {
    if (prefs.tenantExists) {
      final user = (await getCurrentUser())!;
      if (user.tenantId != null) {
        return user;
      }
    }
    var user = (await getCurrentUser())!;
    final tenantId = generateTenantId();
    await prefs.setTenantConfig(
      TenantConfig(
        tenantId: tenantId,
        name: '',
        structure: const TenantStructure(),
      ),
    );
    await prefs.setAdminInviteCode(mockAdminInviteCode);
    user = user.copyWith(
      email: email,
      phone: phone,
      firstName: firstName,
      lastName: lastName,
      displayName: '$firstName $lastName'.trim(),
      tenantId: tenantId,
      onboardingComplete: false,
      isTenantOwner: true,
    );
    _cached = user;
    await _storage.saveProfile(user);
    return user;
  }

  Future<TenantConfig> createBuilding({
    required String tenantId,
    required String name,
    required TenantStructure structure,
    required PreferencesStorage prefs,
  }) async {
    final existing = prefs.getTenantConfig();
    if (existing == null || existing.tenantId != tenantId) {
      throw TenantSetupException('Tenant not found');
    }
    final updated = existing.copyWith(name: name, structure: structure);
    await prefs.setTenantConfig(updated);
    var user = (await getCurrentUser())!;
    user = user.copyWith(onboardingComplete: true);
    _cached = user;
    await _storage.saveProfile(user);
    return updated;
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
