import 'package:url_launcher/url_launcher.dart';

/// Builds a UPI payment intent URL that any UPI app (GPay / PhonePe / Paytm /
/// BHIM) will recognize and pre-fill. Spec: NPCI UPI deep-link.
class UpiLink {
  /// [vpa] — payee virtual address e.g. `ramu@oksbi`
  /// [name] — payee display name shown in the UPI app
  /// [amount] — INR, two decimals
  /// [note] — transaction note shown to payer
  static Uri build({
    required String vpa,
    required String name,
    required double amount,
    String note = 'Milk bill',
  }) {
    final params = {
      'pa': vpa,
      'pn': name,
      'am': amount.toStringAsFixed(2),
      'cu': 'INR',
      'tn': note,
    };
    return Uri(scheme: 'upi', host: 'pay', queryParameters: params);
  }

  /// Launches the UPI app picker. Returns true if a UPI app handled the link.
  /// On web/desktop where no UPI app is installed, returns false — caller
  /// should show a "Pay this UPI ID: ..." fallback dialog.
  static Future<bool> launch({
    required String vpa,
    required String name,
    required double amount,
    String note = 'Milk bill',
  }) async {
    final uri = build(vpa: vpa, name: name, amount: amount, note: note);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
