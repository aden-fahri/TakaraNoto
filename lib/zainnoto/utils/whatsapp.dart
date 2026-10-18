import 'package:url_launcher/url_launcher.dart';

/// Normalisasi nomor HP Indonesia ke digit wa.me (awalan 62).
/// `0812…` → `62812…`, `812…` → `62812…`, `62812…` tetap.
String? whatsappDigits(String? phone) {
  if (phone == null) return null;
  var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  if (digits.startsWith('620')) {
    digits = '62${digits.substring(3)}';
  } else if (digits.startsWith('0')) {
    digits = '62${digits.substring(1)}';
  } else if (!digits.startsWith('62')) {
    digits = '62$digits';
  }
  return digits;
}

/// Deep link wa.me; null jika nomor tidak bisa dipakai.
Uri? whatsappUri(String? phone, {String? message}) {
  final digits = whatsappDigits(phone);
  if (digits == null) return null;
  final query = (message == null || message.isEmpty)
      ? ''
      : '?text=${Uri.encodeComponent(message)}';
  return Uri.parse('https://wa.me/$digits$query');
}

/// Membuka chat WhatsApp; false jika nomor kosong atau gagal dibuka.
Future<bool> openWhatsApp(String? phone, {String? message}) async {
  final uri = whatsappUri(phone, message: message);
  if (uri == null) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
