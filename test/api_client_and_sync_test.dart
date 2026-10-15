import 'package:flutter_test/flutter_test.dart';
import 'package:milk_delivery/core/utils/upi_payment.dart';
import 'package:milk_delivery/core/utils/whatsapp_templates.dart';
import 'package:milk_delivery/data/models/society.dart';
import 'package:milk_delivery/data/models/flat.dart';
import 'package:milk_delivery/data/models/daily_delivery.dart';
import 'package:milk_delivery/data/models/change_request.dart';
import 'package:milk_delivery/data/models/milkman_absence.dart';

void main() {
  group('Backend Serialization & Compatibility Tests', () {
    test('Society deserializes from backend snake_case and camelCase', () {
      final backendJson = {
        'id': 'soc-100',
        'milkman_id': 'milkman-1',
        'name': 'Gokul Dham',
        'address': 'Sector 10',
      };
      final soc = Society.fromJson(backendJson);
      expect(soc.id, 'soc-100');
      expect(soc.milkmanId, 'milkman-1');
      expect(soc.name, 'Gokul Dham');
    });

    test('Flat deserializes from backend snake_case with boolean int flag', () {
      final backendJson = {
        'id': 'flat-100',
        'society_id': 'soc-100',
        'flat_number': 'A-501',
        'owner_name': 'Aarav Sharma',
        'owner_phone': '+919876543210',
        'has_app': 1,
        'default_quantity': 2.5,
        'price_per_litre': 65.0,
        'status': 'active',
      };
      final flat = Flat.fromJson(backendJson);
      expect(flat.id, 'flat-100');
      expect(flat.societyId, 'soc-100');
      expect(flat.flatNumber, 'A-501');
      expect(flat.hasApp, true);
      expect(flat.defaultQuantity, 2.5);
      expect(flat.pricePerLitre, 65.0);
    });

    test('DailyDelivery deserializes from backend delivery record with notes', () {
      final backendJson = {
        'id': 'del-100',
        'flat_id': 'flat-100',
        'date_key': '2026-10-03',
        'planned_quantity': 2.0,
        'actual_quantity': 2.0,
        'status': 'delivered',
        'notes': '+ 1x A2 Gir Cow Bilona Ghee (500ml)',
        'delivered_at': '2026-10-03T06:30:00.000Z',
      };
      final deliv = DailyDelivery.fromJson(backendJson);
      expect(deliv.id, 'del-100');
      expect(deliv.flatId, 'flat-100');
      expect(deliv.status, DeliveryStatus.delivered);
      expect(deliv.notes, '+ 1x A2 Gir Cow Bilona Ghee (500ml)');
      expect(deliv.deliveredAt, isNotNull);

      final json = deliv.toJson();
      expect(json['notes'], '+ 1x A2 Gir Cow Bilona Ghee (500ml)');
    });

    test('ChangeRequest deserializes from backend change request', () {
      final backendJson = {
        'id': 'cr-100',
        'flat_id': 'flat-100',
        'type': 'pause',
        'start_date': '2026-10-04',
        'end_date': '2026-10-06',
        'reason': 'Vacation',
        'status': 'pending',
        'created_at': '2026-10-03T10:00:00.000Z',
      };
      final cr = ChangeRequest.fromJson(backendJson);
      expect(cr.id, 'cr-100');
      expect(cr.flatId, 'flat-100');
      expect(cr.type, ChangeRequestType.pause);
      expect(cr.status, ChangeRequestStatus.pending);
      expect(cr.fromDateKey, '2026-10-04');
    });

    test('MilkmanAbsence deserializes from backend absence record', () {
      final backendJson = {
        'id': 'abs-100',
        'milkman_id': 'milkman-1',
        'date_key': '2026-10-05',
        'reason': 'Festival holiday',
        'type': 'singleDay',
        'created_at': '2026-10-03T08:00:00.000Z',
      };
      final abs = MilkmanAbsence.fromJson(backendJson);
      expect(abs.id, 'abs-100');
      expect(abs.milkmanId, 'milkman-1');
      expect(abs.reason, 'Festival holiday');
      expect(abs.fromDateKey, '2026-10-05');
      expect(abs.isRecurring, false);
    });
  });

  group('Track 3: UPI Payment & WhatsApp Templates', () {
    test('UpiPayment builds valid NPCI UPI uri', () {
      final uri = UpiPayment.buildUpiUri(
        vpa: 'milterra@okicici',
        payeeName: 'Milterra Dairy',
        amount: 1950.50,
        transactionNote: 'Milk Bill Flat B-402',
      );

      expect(uri, startsWith('upi://pay?'));
      expect(uri, contains('pa=milterra%40okicici'));
      expect(uri, contains('pn=Milterra%20Dairy'));
      expect(uri, contains('am=1950.50'));
      expect(uri, contains('cu=INR'));
      expect(uri, contains('tn=Milk%20Bill%20Flat%20B-402'));
    });

    test('UpiPayment falls back to default VPA when empty', () {
      final uri = UpiPayment.buildUpiUri(
        vpa: '  ',
        payeeName: '',
        amount: 500,
        transactionNote: 'Test Note',
      );
      expect(uri, contains('pa=milterra%40upi'));
      expect(uri, contains('pn=Milterra%20Pure%20Dairy'));
      expect(uri, contains('am=500.00'));
    });

    test('WhatsAppTemplates generates morning delivery alert with notes', () {
      final msg = WhatsAppTemplates.morningDeliveryAlert(
        ownerName: 'Sunita Sharma',
        flatNumber: 'A-301',
        quantity: 1.5,
        time: '06:15 AM',
        notes: '+ 1x Desi Makhan (250g)',
      );
      expect(msg, contains('Flat A-301'));
      expect(msg, contains('daily fresh milk (1.5L)'));
      expect(msg, contains('06:15 AM'));
      expect(msg, contains('Included Items: + 1x Desi Makhan (250g)'));
    });

    test('WhatsAppTemplates generates monthly bill notice with UPI details', () {
      final msg = WhatsAppTemplates.monthlyBillNotice(
        ownerName: 'Pooja Verma',
        flatNumber: 'C-104',
        month: 'October 2026',
        amount: 2100.0,
        daysDelivered: 30,
        totalLitres: 45.0,
        upiVpa: 'milterra@upi',
      );
      expect(msg, contains('Pooja Verma'));
      expect(msg, contains('C-104'));
      expect(msg, contains('₹2100.00'));
      expect(msg, contains('milterra@upi'));
      expect(msg, contains('upi://pay?'));
    });

    test('WhatsAppTemplates generates payment confirmation receipt', () {
      final receipt = WhatsAppTemplates.paymentReceived(
        ownerName: 'Pooja Verma',
        flatNumber: 'C-104',
        month: 'October 2026',
        amount: 2100.0,
      );
      expect(receipt, contains('Pooja Verma'));
      expect(receipt, contains('Payment Received with Thanks'));
      expect(receipt, contains('₹2100.00'));
    });
  });
}
