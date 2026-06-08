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
      final parts = json.split('|');
      if (parts.length < 3) return null;
      return UserProfile(
        userId: parts[0],
        email: parts[1],
        displayName: parts[2],
        tenantId: parts.length > 3 && parts[3].isNotEmpty ? parts[3] : null,
        onboardingComplete: parts.length > 4 && parts[4] == 'true',
        isTenantOwner: parts.length > 5 && parts[5] == 'true',
        idToken: parts.length > 6 && parts[6].isNotEmpty ? parts[6] : null,
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
      profile.tenantId ?? '',
      profile.onboardingComplete.toString(),
      profile.isTenantOwner.toString(),
      profile.idToken ?? '',
    ].join('|');
    await _storage.write(key: _profileKey, value: serialized);
  }

  Future<void> clear() async {
    await _storage.delete(key: _profileKey);
  }
}
