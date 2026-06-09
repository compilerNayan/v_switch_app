import 'package:flutter_test/flutter_test.dart';

import 'package:water_meter_app/core/provisioning/internet_reachability_service.dart';
import 'package:water_meter_app/core/provisioning/wifi_ssid_service.dart';

class _FakeWifiSsidService extends WifiSsidService {
  _FakeWifiSsidService({
    required this.onWifi,
    required this.ssid,
  }) : super();

  final bool onWifi;
  final String ssid;

  @override
  Future<bool> isConnectedToWifi() async => onWifi;

  @override
  Future<String> getCurrentSsid() async => ssid;
}

void main() {
  test('returns false when not on WiFi', () async {
    final service = InternetReachabilityService(
      wifiSsidService: _FakeWifiSsidService(onWifi: false, ssid: ''),
      internetProbe: () async => true,
    );

    expect(await service.canReachCloud(), isFalse);
  });

  test('returns false when still on IoT hotspot', () async {
    final service = InternetReachabilityService(
      wifiSsidService: _FakeWifiSsidService(onWifi: true, ssid: 'IoT_WM123'),
      internetProbe: () async => true,
    );

    expect(await service.canReachCloud(), isFalse);
  });

  test('returns true on home WiFi when internet probe succeeds', () async {
    final service = InternetReachabilityService(
      wifiSsidService: _FakeWifiSsidService(onWifi: true, ssid: 'HomeWiFi'),
      internetProbe: () async => true,
    );

    expect(await service.canReachCloud(), isTrue);
  });

  test('returns false when internet probe fails', () async {
    final service = InternetReachabilityService(
      wifiSsidService: _FakeWifiSsidService(onWifi: true, ssid: 'HomeWiFi'),
      internetProbe: () async => false,
    );

    expect(await service.canReachCloud(), isFalse);
  });
}
