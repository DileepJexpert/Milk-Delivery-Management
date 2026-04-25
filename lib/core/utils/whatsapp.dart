import 'package:url_launcher/url_launcher.dart';

class WhatsAppLink {
  /// Open WhatsApp with a pre-filled message. [phone] should include country
  /// code without `+` (e.g. `919876543210`); a leading `+` or spaces are
  /// stripped automatically.
  static Future<bool> send(String phone, String message) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    final uri = Uri.parse(
      'https://wa.me/$cleaned?text=${Uri.encodeComponent(message)}',
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
