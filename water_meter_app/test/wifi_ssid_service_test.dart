import 'package:flutter_test/flutter_test.dart';

import 'package:water_meter_app/core/provisioning/wifi_ssid_service.dart';

void main() {
  group('WifiSsidService', () {
    test('normalizeSsid strips quotes and unknown values', () {
      expect(WifiSsidService.normalizeSsid('"IoT_ABC123"'), 'IoT_ABC123');
      expect(WifiSsidService.normalizeSsid('<unknown ssid>'), '');
      expect(WifiSsidService.normalizeSsid(null), '');
    });

    test('isOnIotHotspot detects IoT_ prefix', () {
      expect(WifiSsidService.isOnIotHotspot('IoT_ABC123'), isTrue);
      expect(WifiSsidService.isOnIotHotspot('HomeWiFi'), isFalse);
      expect(WifiSsidService.isOnIotHotspot(''), isFalse);
    });

    test('extractSerialFromSsid strips prefix', () {
      expect(
        WifiSsidService.extractSerialFromSsid('IoT_WM001'),
        'WM001',
      );
      expect(WifiSsidService.extractSerialFromSsid('HomeWiFi'), isNull);
      expect(WifiSsidService.extractSerialFromSsid('IoT_'), isNull);
    });

    test('canEnroll requires home wifi with saved serial', () {
      expect(
        WifiSsidService.canEnroll(
          savedSerial: 'WM001',
          currentSsid: 'HomeWiFi',
          isOnWifi: true,
        ),
        isTrue,
      );
      expect(
        WifiSsidService.canEnroll(
          savedSerial: 'WM001',
          currentSsid: 'IoT_WM001',
          isOnWifi: true,
        ),
        isFalse,
      );
      expect(
        WifiSsidService.canEnroll(
          savedSerial: null,
          currentSsid: 'HomeWiFi',
          isOnWifi: true,
        ),
        isFalse,
      );
    });
  });
}
