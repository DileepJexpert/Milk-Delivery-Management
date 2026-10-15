import 'package:flutter_test/flutter_test.dart';
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

    test('DailyDelivery deserializes from backend delivery record', () {
      final backendJson = {
        'id': 'del-100',
        'flat_id': 'flat-100',
        'date_key': '2026-10-03',
        'planned_quantity': 2.0,
        'actual_quantity': 2.0,
        'status': 'delivered',
        'delivered_at': '2026-10-03T06:30:00.000Z',
      };
      final deliv = DailyDelivery.fromJson(backendJson);
      expect(deliv.id, 'del-100');
      expect(deliv.flatId, 'flat-100');
      expect(deliv.status, DeliveryStatus.delivered);
      expect(deliv.deliveredAt, isNotNull);
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
}
