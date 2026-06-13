import 'package:flutter_test/flutter_test.dart';

import 'package:water_meter_app/core/live/live_update_message.dart';

void main() {
  group('LiveUpdateMessage', () {
    test('parses water_flow payload', () {
      final message = LiveUpdateMessage.fromJson({
        'type': 'water_flow',
        'tenantId': 'tenant-1',
        'deviceId': 'WM000001',
        'unitId': 'wm-WM000001',
        'ts': '2026-06-09T10:30:05Z',
        'ml': 45,
        'flowRateLpm': 2.7,
        'cumulativeLiters': 123.45,
        'status': 'flowing',
      });

      expect(message, isA<LiveUpdateWaterFlow>());
      final flow = message as LiveUpdateWaterFlow;
      expect(flow.deviceId, 'WM000001');
      expect(flow.flowRateLpm, 2.7);
      expect(flow.cumulativeLiters, 123.45);
      expect(flow.status, 'flowing');
    });

    test('parses bucket_30m refresh signal', () {
      final message = LiveUpdateMessage.fromJson({
        'type': 'bucket_30m',
        'tenantId': 'tenant-1',
        'deviceId': 'WM000001',
        'unitId': 'wm-WM000001',
        'periodStart': '2026-06-09T10:00:00Z',
        'action': 'refresh',
      });

      expect(message, isA<LiveUpdateBucket30m>());
      final bucket = message as LiveUpdateBucket30m;
      expect(bucket.action, 'refresh');
      expect(bucket.periodStart, '2026-06-09T10:00:00Z');
    });
  });
}
