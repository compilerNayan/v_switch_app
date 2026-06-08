import 'package:flutter_test/flutter_test.dart';
import 'package:water_meter_app/core/utils/contact_launcher.dart';

void main() {
  test('normalizePhone strips spaces and dashes', () {
    expect(normalizePhone('+91 98765-43210'), '+919876543210');
  });

  test('digitsOnly keeps digits only', () {
    expect(digitsOnly('+91 98765 43210'), '919876543210');
  });

  test('hasCallablePhone requires at least 7 digits', () {
    expect(hasCallablePhone(null), isFalse);
    expect(hasCallablePhone(''), isFalse);
    expect(hasCallablePhone('12345'), isFalse);
    expect(hasCallablePhone('+91 9876543210'), isTrue);
  });

  test('telUri and whatsAppUri build expected URIs', () {
    expect(telUri('9876543210')?.toString(), 'tel:9876543210');
    expect(whatsAppUri('9876543210')?.toString(), 'https://wa.me/9876543210');
    expect(telUri('123'), isNull);
  });

  test('isValidPhoneInput allows empty optional field', () {
    expect(isValidPhoneInput(null), isTrue);
    expect(isValidPhoneInput(''), isTrue);
    expect(isValidPhoneInput('abc'), isFalse);
    expect(isValidPhoneInput('9876543210'), isTrue);
  });
}
