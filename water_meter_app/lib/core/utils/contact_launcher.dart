import 'package:url_launcher/url_launcher.dart';

String normalizePhone(String phone) {
  return phone.replaceAll(RegExp(r'[\s\-()]'), '');
}

String digitsOnly(String phone) {
  return normalizePhone(phone).replaceAll(RegExp(r'[^\d]'), '');
}

bool hasCallablePhone(String? phone) {
  if (phone == null || phone.trim().isEmpty) return false;
  return digitsOnly(phone).length >= 7;
}

Uri? telUri(String phone) {
  if (!hasCallablePhone(phone)) return null;
  final normalized = normalizePhone(phone.trim());
  return Uri(scheme: 'tel', path: normalized);
}

Uri? whatsAppUri(String phone) {
  final digits = digitsOnly(phone);
  if (digits.length < 7) return null;
  return Uri.parse('https://wa.me/$digits');
}

bool isValidPhoneInput(String? value) {
  if (value == null || value.trim().isEmpty) return true;
  final digits = digitsOnly(value);
  return digits.length >= 7 && digits.length <= 15;
}

Future<bool> launchPhoneCall(String phone) async {
  final uri = telUri(phone);
  if (uri == null) return false;
  return launchUrl(uri);
}

Future<bool> launchWhatsAppChat(String phone) async {
  final uri = whatsAppUri(phone);
  if (uri == null) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
