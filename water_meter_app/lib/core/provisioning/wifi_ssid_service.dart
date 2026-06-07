import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class WifiSsidService {
  WifiSsidService({
    NetworkInfo? networkInfo,
    Connectivity? connectivity,
  })  : _networkInfo = networkInfo ?? NetworkInfo(),
        _connectivity = connectivity ?? Connectivity();

  static const iotSsidPrefix = 'IoT_';

  final NetworkInfo _networkInfo;
  final Connectivity _connectivity;

  static String normalizeSsid(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final trimmed = raw.trim().replaceAll('"', '');
    if (trimmed == '<unknown ssid>' || trimmed.toLowerCase() == 'null') {
      return '';
    }
    return trimmed;
  }

  static bool isOnIotHotspot(String ssid) =>
      ssid.isNotEmpty && ssid.startsWith(iotSsidPrefix);

  static String? extractSerialFromSsid(String ssid) {
    if (!isOnIotHotspot(ssid)) return null;
    final serial = ssid.substring(iotSsidPrefix.length).trim();
    return serial.isEmpty ? null : serial;
  }

  static bool canEnroll({
    required String? savedSerial,
    required String currentSsid,
    required bool isOnWifi,
  }) {
    if (savedSerial == null || savedSerial.trim().isEmpty) return false;
    if (!isOnWifi) return false;
    if (currentSsid.isEmpty) return false;
    return !isOnIotHotspot(currentSsid);
  }

  Future<bool> requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  Future<bool> hasLocationPermission() async {
    return Permission.locationWhenInUse.isGranted;
  }

  Future<bool> isConnectedToWifi() async {
    final results = await _connectivity.checkConnectivity();
    return results.contains(ConnectivityResult.wifi);
  }

  Future<String> getCurrentSsid() async {
    if (!await hasLocationPermission()) {
      return '';
    }
    final wifiName = await _networkInfo.getWifiName();
    return normalizeSsid(wifiName);
  }
}
