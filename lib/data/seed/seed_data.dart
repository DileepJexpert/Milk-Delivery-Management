import 'package:uuid/uuid.dart';

import '../../core/utils/date_utils.dart';
import '../local/local_store.dart';
import '../models/daily_delivery.dart';
import '../models/flat.dart';
import '../models/society.dart';
import '../models/user.dart';

/// Deterministic seed data so the app is usable on first launch.
/// Default milkman: phone `9000000001`, OTP `123456`.
/// Default subscribers (have flats pre-linked): `9111111111`, `9222222222`.
class SeedData {
  static const _uuid = Uuid();
  static const _seededFlag = 'seeded_v1';

  static Future<void> ensureSeeded() async {
    final settings = LocalStore.instance.settings;
    if (settings.get(_seededFlag) == true) return;

    final milkman = AppUser(
      id: 'milkman-1',
      phone: '9000000001',
      name: 'Ramu Milkman',
      role: UserRole.milkman,
    );
    final sub1 = AppUser(
      id: 'sub-1',
      phone: '9111111111',
      name: 'Asha Sharma',
      role: UserRole.subscriber,
    );
    final sub2 = AppUser(
      id: 'sub-2',
      phone: '9222222222',
      name: 'Rajiv Kumar',
      role: UserRole.subscriber,
    );

    await LocalStore.instance.users.put(milkman.id, milkman.toJson());
    await LocalStore.instance.users.put(sub1.id, sub1.toJson());
    await LocalStore.instance.users.put(sub2.id, sub2.toJson());

    final greenPark = Society(
      id: _uuid.v4(),
      milkmanId: milkman.id,
      name: 'Green Park Apartments',
      address: 'Sector 12, Noida',
    );
    final lotusVilla = Society(
      id: _uuid.v4(),
      milkmanId: milkman.id,
      name: 'Lotus Villa',
      address: 'MG Road, Bengaluru',
    );
    await LocalStore.instance.societies.put(greenPark.id, greenPark.toJson());
    await LocalStore.instance.societies.put(lotusVilla.id, lotusVilla.toJson());

    final flats = <Flat>[
      Flat(
        id: _uuid.v4(),
        societyId: greenPark.id,
        flatNumber: 'A-101',
        ownerName: sub1.name,
        ownerPhone: sub1.phone,
        hasApp: true,
        defaultQuantity: 1.0,
        pricePerLitre: 60,
      ),
      Flat(
        id: _uuid.v4(),
        societyId: greenPark.id,
        flatNumber: 'A-102',
        ownerName: 'Vikram Singh',
        ownerPhone: '9333333333',
        hasApp: false,
        defaultQuantity: 2.0,
        pricePerLitre: 60,
      ),
      Flat(
        id: _uuid.v4(),
        societyId: greenPark.id,
        flatNumber: 'B-204',
        ownerName: 'Meera Patel',
        ownerPhone: '9444444444',
        hasApp: false,
        defaultQuantity: 0.5,
        pricePerLitre: 60,
      ),
      Flat(
        id: _uuid.v4(),
        societyId: lotusVilla.id,
        flatNumber: '12',
        ownerName: sub2.name,
        ownerPhone: sub2.phone,
        hasApp: true,
        defaultQuantity: 1.5,
        pricePerLitre: 65,
      ),
      Flat(
        id: _uuid.v4(),
        societyId: lotusVilla.id,
        flatNumber: '15',
        ownerName: 'Sunita Rao',
        ownerPhone: '9555555555',
        hasApp: false,
        defaultQuantity: 1.0,
        pricePerLitre: 65,
      ),
    ];
    for (final f in flats) {
      await LocalStore.instance.flats.put(f.id, f.toJson());
    }

    // Backfill a handful of past days so the history/billing screens are
    // populated immediately.
    final today = AppDates.today();
    for (int daysBack = 7; daysBack >= 1; daysBack--) {
      final d = today.subtract(Duration(days: daysBack));
      final key = AppDates.dateKey(d);
      for (final f in flats) {
        final delivered = !(daysBack == 3 && f.flatNumber == 'A-101');
        final delivery = DailyDelivery(
          id: _uuid.v4(),
          flatId: f.id,
          dateKey: key,
          plannedQuantity: f.defaultQuantity,
          actualQuantity: delivered ? f.defaultQuantity : 0,
          status: delivered ? DeliveryStatus.delivered : DeliveryStatus.skipped,
          deliveredAt: delivered
              ? d.add(const Duration(hours: 7, minutes: 15))
              : null,
        );
        await LocalStore.instance.deliveries
            .put(delivery.id, delivery.toJson());
      }
    }

    await settings.put(_seededFlag, true);
  }
}
