import 'upi_payment.dart';

class WhatsAppTemplates {
  WhatsAppTemplates._();

  static String morningDeliveryAlert({
    required String ownerName,
    required String flatNumber,
    required double quantity,
    required String time,
    String? notes,
  }) {
    final noteSection = (notes != null && notes.trim().isNotEmpty)
        ? '\n📦 Included Items: $notes'
        : '';
    return 'Namaste $ownerName ji! 🥛\n\n'
        'Your daily fresh milk (${quantity}L) has been safely delivered at Flat $flatNumber.\n'
        '⏰ Delivered at: $time$noteSection\n\n'
        'Have a healthy and energetic day!\n'
        '- Milterra Pure Dairy';
  }

  static String monthlyBillNotice({
    required String ownerName,
    required String flatNumber,
    required String month,
    required double amount,
    required int daysDelivered,
    required double totalLitres,
    required String upiVpa,
  }) {
    final upiLink = UpiPayment.buildUpiUri(
      vpa: upiVpa,
      payeeName: 'Milterra Pure Dairy',
      amount: amount,
      transactionNote: 'Milk Bill Flat $flatNumber ($month)',
    );
    return 'Namaste $ownerName ji! 📋\n\n'
        'Your Milk Bill for $month (Flat $flatNumber) is ready:\n'
        '• Days Delivered: $daysDelivered days ($totalLitres Litres)\n'
        '• Total Amount Due: ₹${amount.toStringAsFixed(2)}\n\n'
        '💳 Pay instantly via UPI to: $upiVpa\n'
        'Direct UPI Link: $upiLink\n'
        'Or view detailed breakdown: https://delivery.milterra.com\n\n'
        'Thank you for being our valued subscriber! 🙏';
  }

  static String paymentConfirmation({
    required String flatNumber,
    required String month,
    required double amount,
  }) {
    return 'Namaste! ✅\n\n'
        'I have completed the milk bill payment of ₹${amount.toStringAsFixed(2)} for Flat $flatNumber ($month) via UPI.\n\n'
        'Please confirm receipt. Thank you!';
  }

  static String paymentReceived({
    required String ownerName,
    required String flatNumber,
    required String month,
    required double amount,
  }) {
    return 'Namaste $ownerName ji! 🧾\n\n'
        'Payment Received with Thanks: ₹${amount.toStringAsFixed(2)} for Flat $flatNumber ($month).\n\n'
        'Thank you for being our valued subscriber!\n'
        '- Milterra Pure Dairy';
  }
}
