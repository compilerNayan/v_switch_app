import 'package:flutter_test/flutter_test.dart';

import 'package:water_meter_app/core/live/live_update_message.dart';

void main() {
  group('LiveUpdateMessage', () {
    test('parses water_flow_tick payload', () {
      final message = LiveUpdateMessage.fromJson({
        'type': 'water_flow_tick',
        'tenantId': 'tenant-1',
        'ts': '2026-06-09T10:30:05Z',
        'devices': [
          {
            'deviceId': 'WM000001',
            'unitId': 'wm-WM000001',
            'ts': '2026-06-09T10:30:05Z',
            'ml': 45,
            'flowRateLpm': 2.7,
            'cumulativeLiters': 123.45,
            'todayLiters': 18.2,
            'monthLiters': 14532.5,
            'status': 'flowing',
          },
          {
            'deviceId': 'WM000002',
            'unitId': 'wm-WM000002',
            'ts': '2026-06-09T10:30:05Z',
            'ml': 30,
            'flowRateLpm': 1.8,
            'cumulativeLiters': 88.1,
            'status': 'flowing',
          },
        ],
      });

      expect(message, isA<LiveUpdateWaterFlowTick>());
      final tick = message as LiveUpdateWaterFlowTick;
      expect(tick.tenantId, 'tenant-1');
      expect(tick.devices, hasLength(2));
      expect(tick.devices.first.deviceId, 'WM000001');
      expect(tick.devices.first.flowRateLpm, 2.7);
      expect(tick.devices.first.todayLiters, 18.2);
      expect(tick.devices.first.monthLiters, 14532.5);
      expect(tick.devices.last.deviceId, 'WM000002');
    });

    test('parses legacy water_flow payload', () {
      final message = LiveUpdateMessage.fromJson({
        'type': 'water_flow',
        'tenantId': 'tenant-1',
        'deviceId': 'WM000001',
        'unitId': 'wm-WM000001',
        'ts': '2026-06-09T10:30:05Z',
        'ml': 45,
        'flowRateLpm': 2.7,
        'cumulativeLiters': 123.45,
        'todayLiters': 9.8,
        'status': 'flowing',
      });

      expect(message, isA<LiveUpdateWaterFlow>());
      final flow = message as LiveUpdateWaterFlow;
      expect(flow.deviceId, 'WM000001');
      expect(flow.flowRateLpm, 2.7);
      expect(flow.cumulativeLiters, 123.45);
      expect(flow.todayLiters, 9.8);
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
    test('parses device_presence offline payload', () {
      final message = LiveUpdateMessage.fromJson({
        'type': 'device_presence',
        'tenantId': 'tenant-1',
        'deviceId': 'WM000001',
        'unitId': 'wm-WM000001',
        'ts': '2026-06-09T10:30:35Z',
        'status': 'offline',
      });

      expect(message, isA<LiveUpdateDevicePresence>());
      final presence = message as LiveUpdateDevicePresence;
      expect(presence.deviceId, 'WM000001');
      expect(presence.isOnline, isFalse);
    });

    test('parses device_presence online payload', () {
      final message = LiveUpdateMessage.fromJson({
        'type': 'device_presence',
        'tenantId': 'tenant-1',
        'deviceId': 'WM000001',
        'unitId': 'wm-WM000001',
        'ts': '2026-06-09T10:30:36Z',
        'status': 'online',
      });

      expect(message, isA<LiveUpdateDevicePresence>());
      expect((message as LiveUpdateDevicePresence).isOnline, isTrue);
    });
  });
}
