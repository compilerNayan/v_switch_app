import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Firebase Cloud Messaging wrapper. No-op in mock/web until google-services is configured.
final pushServiceProvider = Provider<PushService>((ref) => PushService());

class PushService {
  Future<void> initialize() async {
    if (kIsWeb) return;
    // FCM registration stub — wire firebase_messaging when google-services.json is added.
  }

  Future<String?> getToken() async => null;

  Future<void> registerTokenWithBackend(String token) async {
    // POST /users/me/push-token stub for production.
  }
}
