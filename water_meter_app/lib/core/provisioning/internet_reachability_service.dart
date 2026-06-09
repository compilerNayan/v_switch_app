import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'wifi_ssid_service.dart';

/// Verifies the phone is on regular WiFi (not the device hotspot) and can reach the cloud.
class InternetReachabilityService {
  InternetReachabilityService({
    WifiSsidService? wifiSsidService,
    Dio? dio,
    Future<bool> Function()? internetProbe,
  })  : _wifiSsidService = wifiSsidService ?? WifiSsidService(),
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 5),
              ),
            ),
        _internetProbe = internetProbe;

  final WifiSsidService _wifiSsidService;
  final Dio _dio;
  final Future<bool> Function()? _internetProbe;

  /// True when connected to non-IoT WiFi and the API host responds (DNS + internet).
  Future<bool> canReachCloud() async {
    if (!await _wifiSsidService.isConnectedToWifi()) {
      return false;
    }

    final ssid = await _wifiSsidService.getCurrentSsid();
    if (WifiSsidService.isOnIotHotspot(ssid)) {
      return false;
    }

    return _internetProbe != null ? _internetProbe!() : _probeInternet();
  }

  Future<bool> _probeInternet() async {
    try {
      final uri = Uri.parse(AppConfig.apiBaseUrl);
      if (uri.host.isEmpty) {
        return false;
      }
      final response = await _dio.head(
        '${uri.scheme}://${uri.host}',
        options: Options(validateStatus: (status) => status != null && status < 500),
      );
      return response.statusCode != null;
    } catch (_) {
      return false;
    }
  }
}
