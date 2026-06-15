import 'package:flutter_test/flutter_test.dart';

import 'package:water_meter_app/core/api/api_exceptions.dart';

void main() {
  test('parses nested API error object', () {
    final error = ApiError.fromJson({
      'error': {'code': 'FORBIDDEN', 'message': 'Not allowed'},
    });
    expect(error.code, 'FORBIDDEN');
    expect(error.message, 'Not allowed');
  });

  test('parses Spring Boot error string', () {
    final error = ApiError.fromJson({
      'timestamp': '2026-06-15T10:00:00.000+00:00',
      'status': 404,
      'error': 'Not Found',
      'path': '/v2/tenants/abc',
    });
    expect(error.code, '404');
    expect(error.message, 'Not Found');
  });
}
