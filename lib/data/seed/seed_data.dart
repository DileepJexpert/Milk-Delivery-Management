import 'package:uuid/uuid.dart';

import '../../core/utils/date_utils.dart';
import '../local/local_store.dart';
import '../models/category.dart';
import '../models/daily_delivery.dart';
import '../models/flat.dart';
import '../models/product.dart';
import '../models/society.dart';
import '../models/subscription.dart';
import '../models/user.dart';

/// Deterministic seed data so the app is usable on first launch.
/// Default milkman: phone `9000000001`, OTP `123456`.
/// Default subscribers (have flats pre-linked): `9111111111`, `9222222222`.
class SeedData {
  static const _uuid = Uuid();
  static const _seededFlag = 'seeded_v1';
  static const _catalogFlag = 'catalog_seeded_v1';
  static const _migratedFlag = 'subscriptions_migrated_v1';

  static Future<void> ensureSeeded() async {
    await _seedV1();
    await _seedCatalog();
    await _migrateFlatsToSubscriptions();
  }

  // ───────────────────── v1: original users / flats / history ─────────────

  static Future<void> _seedV1() async {
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
        billingMode: BillingMode.postpaid,
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
        billingMode: BillingMode.prepaid,
        walletBalance: 500,
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
          productId: '', // gets migrated below
          dateKey: key,
          plannedQuantity: f.defaultQuantity,
          actualQuantity: delivered ? f.defaultQuantity : 0,
          unitPrice: f.pricePerLitre,
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

  // ───────────────────── Catalog: categories + products ───────────────────

  static Future<void> _seedCatalog() async {
    final settings = LocalStore.instance.settings;
    if (settings.get(_catalogFlag) == true) return;

    final dairy = ProductCategory(
      id: 'cat-dairy',
      name: 'Dairy',
      icon: 'local_drink',
      sortOrder: 1,
    );
    final groceries = ProductCategory(
      id: 'cat-groceries',
      name: 'Groceries',
      icon: 'shopping_basket',
      sortOrder: 2,
    );
    final bakery = ProductCategory(
      id: 'cat-bakery',
      name: 'Bakery',
      icon: 'bakery_dining',
      sortOrder: 3,
    );
    await LocalStore.instance.categories.put(dairy.id, dairy.toJson());
    await LocalStore.instance.categories.put(groceries.id, groceries.toJson());
    await LocalStore.instance.categories.put(bakery.id, bakery.toJson());

    final products = <Product>[
      Product(
        id: 'prod-cow-milk',
        categoryId: dairy.id,
        name: 'Cow Milk',
        unit: ProductUnit.litre,
        defaultPrice: 60,
      ),
      Product(
        id: _uuid.v4(),
        categoryId: dairy.id,
        name: 'Buffalo Milk',
        unit: ProductUnit.litre,
        defaultPrice: 70,
      ),
      Product(
        id: _uuid.v4(),
        categoryId: dairy.id,
        name: 'Curd',
        unit: ProductUnit.kg,
        defaultPrice: 80,
      ),
      Product(
        id: _uuid.v4(),
        categoryId: dairy.id,
        name: 'Paneer',
        unit: ProductUnit.kg,
        defaultPrice: 350,
      ),
      Product(
        id: _uuid.v4(),
        categoryId: dairy.id,
        name: 'Ghee',
        unit: ProductUnit.litre,
        defaultPrice: 600,
      ),
      Product(
        id: _uuid.v4(),
        categoryId: bakery.id,
        name: 'Bread',
        unit: ProductUnit.piece,
        defaultPrice: 40,
      ),
      Product(
        id: _uuid.v4(),
        categoryId: groceries.id,
        name: 'Eggs',
        unit: ProductUnit.piece,
        defaultPrice: 8,
      ),
    ];
    for (final p in products) {
      await LocalStore.instance.products.put(p.id, p.toJson());
    }

    await settings.put(_catalogFlag, true);
  }

  // ───────── Migration: existing flats → cow milk subscription ────────────

  static Future<void> _migrateFlatsToSubscriptions() async {
    final settings = LocalStore.instance.settings;
    if (settings.get(_migratedFlag) == true) return;

    const cowMilkId = 'prod-cow-milk';

    // 1. Subscriptions: one per flat using its legacy defaultQuantity.
    final existingSubs = LocalStore.instance.subscriptions.values
        .whereType<Map>()
        .map(Subscription.fromJson)
        .toList();
    final flatsWithSubs = existingSubs.map((s) => s.flatId).toSet();

    for (final raw in LocalStore.instance.flats.values.whereType<Map>()) {
      final flat = Flat.fromJson(raw);
      if (flatsWithSubs.contains(flat.id)) continue;
      if (flat.defaultQuantity <= 0) continue;
      final sub = Subscription(
        id: _uuid.v4(),
        flatId: flat.id,
        productId: cowMilkId,
        quantity: flat.defaultQuantity,
        unitPrice: flat.pricePerLitre,
        status: SubscriptionStatus.active,
        createdAt: DateTime.now(),
      );
      await LocalStore.instance.subscriptions.put(sub.id, sub.toJson());
    }

    // 2. Backfill productId on legacy delivery rows.
    final deliveriesBox = LocalStore.instance.deliveries;
    final toUpdate = <DailyDelivery>[];
    for (final raw in deliveriesBox.values.whereType<Map>()) {
      final d = DailyDelivery.fromJson(raw);
      if (d.productId.isEmpty) {
        toUpdate.add(d.copyWith(productId: cowMilkId));
      }
    }
    for (final d in toUpdate) {
      await deliveriesBox.put(d.id, d.toJson());
    }

    await settings.put(_migratedFlag, true);
  }
}
