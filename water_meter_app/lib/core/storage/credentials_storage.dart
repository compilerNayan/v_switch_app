import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CredentialsStorage {
  CredentialsStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _deviceIdKey = 'device_id';
  static const _apiKeyKey = 'api_key';

  final FlutterSecureStorage _storage;

  Future<({String deviceId, String apiKey})?> read() async {
    final deviceId = await _storage.read(key: _deviceIdKey);
    final apiKey = await _storage.read(key: _apiKeyKey);
    if (deviceId == null ||
        deviceId.isEmpty ||
        apiKey == null ||
        apiKey.isEmpty) {
      return null;
    }
    return (deviceId: deviceId, apiKey: apiKey);
  }

  Future<void> save({
    required String deviceId,
    required String apiKey,
  }) async {
    await _storage.write(key: _deviceIdKey, value: deviceId);
    await _storage.write(key: _apiKeyKey, value: apiKey);
  }

  Future<void> clear() async {
    await _storage.delete(key: _deviceIdKey);
    await _storage.delete(key: _apiKeyKey);
  }
}
