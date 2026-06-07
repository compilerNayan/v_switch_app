import 'package:dio/dio.dart';

sealed class WifiConfigureResult {
  const WifiConfigureResult();
}

class WifiConfigureSuccess extends WifiConfigureResult {
  const WifiConfigureSuccess();
}

class WifiConfigureHttpError extends WifiConfigureResult {
  const WifiConfigureHttpError(this.code);
  final int code;
}

class WifiConfigureNetworkError extends WifiConfigureResult {
  const WifiConfigureNetworkError(this.message);
  final String message;
}

class WifiCredentialsClient {
  WifiCredentialsClient({Dio? dio, this.port = 8080, this.gatewayHost = '192.168.4.1'})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 15),
              ),
            );

  final Dio _dio;
  final int port;
  final String gatewayHost;

  Future<WifiConfigureResult> configureWifi({
    required String homeWifiSsid,
    required String homeWifiPassword,
    required String deviceSerialNumber,
  }) async {
    final payload = {'ssid': homeWifiSsid, 'password': homeWifiPassword};
    final hosts = [gatewayHost, '$deviceSerialNumber.local'];

    var lastHttpCode = -1;
    String? lastNetworkError;

    for (final host in hosts) {
      try {
        final response = await _dio.post<Map<String, dynamic>>(
          'http://$host:$port/wifi-credentials',
          data: payload,
          options: Options(contentType: 'application/json'),
        );
        if (response.statusCode != null &&
            response.statusCode! >= 200 &&
            response.statusCode! < 300) {
          return const WifiConfigureSuccess();
        }
        lastHttpCode = response.statusCode ?? -1;
      } on DioException catch (error) {
        if (error.response?.statusCode != null) {
          lastHttpCode = error.response!.statusCode!;
        } else {
          lastNetworkError = error.message ?? error.type.name;
        }
      } catch (error) {
        lastNetworkError = error.toString();
      }
    }

    if (lastHttpCode > 0) {
      return WifiConfigureHttpError(lastHttpCode);
    }
    return WifiConfigureNetworkError(lastNetworkError ?? 'Unknown network error');
  }
}
