import 'enrollment_client.dart';

/// Simulates device enrollment without a physical water meter.
class MockEnrollmentClient {
  const MockEnrollmentClient({this.delayMs = 400});

  final int delayMs;

  Future<EnrollmentResult> enroll(String deviceSerialNumber) async {
    await Future<void>.delayed(Duration(milliseconds: delayMs));
    if (deviceSerialNumber.isEmpty) {
      return const EnrollmentNetworkError('Missing device serial');
    }
    return const EnrollmentSuccess();
  }
}
