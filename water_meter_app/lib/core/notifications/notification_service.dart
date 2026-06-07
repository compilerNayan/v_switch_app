import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/alert_event.dart';

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());

class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialized = true;
  }

  Future<void> showAlert(AlertEvent alert) async {
    if (kIsWeb) return;
    await initialize();
    final android = AndroidNotificationDetails(
      'water_alerts',
      'Water Alerts',
      channelDescription: 'Quota, leak, and offline alerts',
      importance: alert.type.isCritical
          ? Importance.high
          : Importance.defaultImportance,
      priority: alert.type.isCritical ? Priority.high : Priority.defaultPriority,
    );
    const ios = DarwinNotificationDetails();
    await _plugin.show(
      alert.id.hashCode,
      alert.type.label,
      alert.message,
      NotificationDetails(android: android, iOS: ios),
    );
  }
}
