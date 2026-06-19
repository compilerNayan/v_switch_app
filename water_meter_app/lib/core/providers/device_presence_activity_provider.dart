import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/presence_activity.dart';
import 'app_providers.dart';
import 'unit_providers.dart';

final presenceActivityProvider =
    FutureProvider.autoDispose<PresenceActivityResponse>((ref) async {
  final client = ref.watch(waterApiClientProvider);
  final deviceId = ref.watch(activeDeviceApiIdProvider);
  final timezone = ref.watch(timezoneProvider);
  return client.getPresenceActivity(
    deviceId: deviceId,
    days: 30,
    timezone: timezone,
  );
});

String presenceDateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

DayPresenceActivity? presenceDayForDate(
  PresenceActivityResponse response,
  DateTime date,
) {
  return response.dayFor(presenceDateKey(date));
}
