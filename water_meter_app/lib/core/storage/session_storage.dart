import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user_profile.dart';

/// Persists mock auth profile locally; Amplify manages its own session.
class SessionStorage {
  SessionStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _profileKey = 'user_profile_json';

  final FlutterSecureStorage _storage;

  Future<UserProfile?> readProfile() async {
    final json = await _storage.read(key: _profileKey);
    if (json == null || json.isEmpty) return null;
    try {
      // Simple key=value storage for mock mode
      final parts = json.split('|');
      if (parts.length < 3) return null;
      return UserProfile(
        userId: parts[0],
        email: parts[1],
        displayName: parts[2],
        role: UserRole.fromString(parts.length > 3 ? parts[3] : null),
        tenantId: parts.length > 4 && parts[4].isNotEmpty ? parts[4] : null,
        inviteCode: parts.length > 5 && parts[5].isNotEmpty ? parts[5] : null,
        onboardingComplete: parts.length > 6 && parts[6] == 'true',
        idToken: parts.length > 7 && parts[7].isNotEmpty ? parts[7] : null,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProfile(UserProfile profile) async {
    final serialized = [
      profile.userId,
      profile.email,
      profile.displayName,
      profile.role?.toApiValue() ?? '',
      profile.tenantId ?? '',
      profile.inviteCode ?? '',
      profile.onboardingComplete.toString(),
      profile.idToken ?? '',
    ].join('|');
    await _storage.write(key: _profileKey, value: serialized);
  }

  Future<void> clear() async {
    await _storage.delete(key: _profileKey);
  }
}
