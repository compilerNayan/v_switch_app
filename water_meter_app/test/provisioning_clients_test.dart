import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:water_meter_app/core/provisioning/enrollment_client.dart';
import 'package:water_meter_app/core/provisioning/wifi_credentials_client.dart';

void main() {
  Dio mockDio({required bool succeed}) {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: succeed ? 200 : 500,
            ),
          );
        },
      ),
    );
    return dio;
  }

  group('WifiCredentialsClient', () {
    test('posts home wifi credentials to device gateway', () async {
      final client = WifiCredentialsClient(dio: mockDio(succeed: true));
      final result = await client.configureWifi(
        homeWifiSsid: 'HomeNet',
        homeWifiPassword: 'secret',
        deviceSerialNumber: 'WM001',
      );

      expect(result, isA<WifiConfigureSuccess>());
    });
  });

  group('EnrollmentClient', () {
    test('posts enroll to device mDNS host', () async {
      final client = EnrollmentClient(dio: mockDio(succeed: true));
      final result = await client.enroll('WM001');

      expect(result, isA<EnrollmentSuccess>());
    });

    test('returns http error on failure', () async {
      final client = EnrollmentClient(dio: mockDio(succeed: false));
      final result = await client.enroll('WM001');

      expect(result, isA<EnrollmentHttpError>());
    });
  });
}
