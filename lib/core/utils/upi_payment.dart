import 'package:url_launcher/url_launcher.dart';

class UpiPayment {
  UpiPayment._();

  static const String defaultVpa = 'milterra@upi';
  static const String defaultPayeeName = 'Milterra Pure Dairy';

  /// Builds a standard UPI payment URI compatible with NPCI guidelines:
  /// `upi://pay?pa=...&pn=...&am=...&cu=INR&tn=...`
  static String buildUpiUri({
    required String vpa,
    required String payeeName,
    required double amount,
    required String transactionNote,
  }) {
    final cleanVpa = vpa.trim().isEmpty ? defaultVpa : vpa.trim();
    final cleanName = payeeName.trim().isEmpty ? defaultPayeeName : payeeName.trim();
    final cleanAmount = amount.toStringAsFixed(2);

    return 'upi://pay?'
        'pa=${Uri.encodeComponent(cleanVpa)}&'
        'pn=${Uri.encodeComponent(cleanName)}&'
        'am=$cleanAmount&'
        'cu=INR&'
        'tn=${Uri.encodeComponent(transactionNote)}';
  }

  /// Launches any installed UPI app (Google Pay, PhonePe, Paytm, BHIM) on Android/iOS.
  static Future<bool> launchUpiIntent({
    required String vpa,
    required String payeeName,
    required double amount,
    required String transactionNote,
  }) async {
    final uriString = buildUpiUri(
      vpa: vpa,
      payeeName: payeeName,
      amount: amount,
      transactionNote: transactionNote,
    );
    final uri = Uri.parse(uriString);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
