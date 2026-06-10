import 'package:flutter_test/flutter_test.dart';
import 'package:water_meter_app/core/utils/timezone_offset.dart';

void main() {
  test('localTimezoneOffsetParam formats offset with sign', () {
    final offset = DateTime.now().timeZoneOffset;
    final expectedSign = offset.isNegative ? '-' : '+';
    expect(localTimezoneOffsetParam(), startsWith(expectedSign));
    expect(localTimezoneOffsetParam(), contains(':'));
  });
}
