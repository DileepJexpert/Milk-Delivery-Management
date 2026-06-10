import 'package:uuid/uuid.dart';

import '../../core/utils/date_utils.dart';
import '../local/local_store.dart';
import '../local/sync_queue.dart';
import '../models/audit_log.dart';
import '../models/daily_delivery.dart';
import '../models/flat.dart' show Flat, FlatStatus, BillingMode;
import '../models/subscription.dart';
import '../models/user.dart';
import 'audit_repository.dart';
import 'flat_repository.dart';
import 'subscription_repository.dart';
import 'wallet_repository.dart';

class DeliveryRepository {
  DeliveryRepository(this._flats, this._audit, this._subscriptions, this._wallet);

  final FlatRepository _flats;
  final AuditRepository _audit;
  final SubscriptionRepository _subscriptions;
  final WalletRepository _wallet;
  static const _uuid = Uuid();

  Stream<List<DailyDelivery>> watchForDate(
    String dateKey,
    Iterable<String> flatIds,
  ) async* {
    final ids = flatIds.toSet();
    yield _allForDate(dateKey).where((d) => ids.contains(d.flatId)).toList();
    yield* LocalStore.instance.deliveries.watch().map(
          (_) => _allForDate(dateKey)
              .where((d) => ids.contains(d.flatId))
              .toList(),
        );
  }

  Stream<List<DailyDelivery>> watchForFlat(String flatId) async* {
    yield _allForFlat(flatId);
    yield* LocalStore.instance.deliveries
        .watch()
        .map((_) => _allForFlat(flatId));
  }

  List<DailyDelivery> _allForDate(String dateKey) =>
      LocalStore.instance.deliveries.values
          .whereType<Map>()
          .map(DailyDelivery.fromJson)
          .where((d) => d.dateKey == dateKey)
          .toList();

  List<DailyDelivery> _allForFlat(String flatId) =>
      LocalStore.instance.deliveries.values
          .whereType<Map>()
          .map(DailyDelivery.fromJson)
          .where((d) => d.flatId == flatId)
          .toList()
        ..sort((a, b) => b.dateKey.compareTo(a.dateKey));

  /// Convenience pass-through so dependent repositories (change requests,
  /// absences) don't need a direct dependency on SubscriptionRepository.
  List<Subscription> subscriptionsForFlat(String flatId) =>
      _subscriptions.activeForFlat(flatId);

  /// Returns the row for a specific (flat, product, date) — creating it from
  /// the active subscription if it doesn't exist yet.
  DailyDelivery ensureForSubscription(
    Flat flat,
    Subscription sub, {
    DateTime? when,
  }) {
    final date = when ?? AppDates.today();
    final key = AppDates.dateKey(date);
    final existing = LocalStore.instance.deliveries.values
        .whereType<Map>()
        .map(DailyDelivery.fromJson)
        .where((d) =>
            d.flatId == flat.id &&
            d.productId == sub.productId &&
            d.dateKey == key)
        .toList();
    if (existing.isNotEmpty) return existing.first;

    final initialStatus = flat.status == FlatStatus.active
        ? DeliveryStatus.pending
        : DeliveryStatus.paused;
    final fresh = DailyDelivery(
      id: _uuid.v4(),
      flatId: flat.id,
      productId: sub.productId,
      dateKey: key,
      plannedQuantity: sub.quantity,
      actualQuantity: 0,
      unitPrice: sub.unitPrice,
      status: initialStatus,
    );
    if (flat.status != FlatStatus.stopped) {
      LocalStore.instance.deliveries.put(fresh.id, fresh.toJson());
    }
    return fresh;
  }

  /// For every active subscription on every (non-stopped) flat, ensure a
  /// delivery row exists for today.
  Future<List<DailyDelivery>> ensureRouteForToday(List<Flat> flats) async {
    final out = <DailyDelivery>[];
    for (final f in flats) {
      if (f.status == FlatStatus.stopped) continue;
      final subs = _subscriptions.activeForFlat(f.id);
      for (final s in subs) {
        out.add(ensureForSubscription(f, s));
      }
    }
    return out;
  }

  Future<DailyDelivery> markDelivered(
    DailyDelivery row,
    AppUser actor, {
    double? quantity,
    String? reason,
    String? proofPhotoB64,
  }) async {
    final qty = quantity ?? row.plannedQuantity;
    final updated = row.copyWith(
      status: DeliveryStatus.delivered,
      actualQuantity: qty,
      deliveredAt: DateTime.now(),
      proofPhotoB64: proofPhotoB64,
    );
    await _persist(updated);
    await _audit.log(
      flatId: row.flatId,
      actor: actor,
      type: AuditChangeType.deliveryMarked,
      oldValue: '${row.status.name} ${row.actualQuantity}',
      newValue: '${updated.status.name} ${updated.actualQuantity}',
      reason: reason,
    );
    // Auto-debit for prepaid flats.
    final flat = _flats.byId(row.flatId);
    if (flat != null &&
        flat.billingMode == BillingMode.prepaid &&
        updated.unitPrice > 0 &&
        qty > 0) {
      final amount = qty * updated.unitPrice;
      await _wallet.debit(
        flat,
        actor,
        amount,
        relatedDeliveryId: updated.id,
        reason: 'auto-debit',
      );
    }
    return updated;
  }

  Future<DailyDelivery> markSkipped(
    DailyDelivery row,
    AppUser actor, {
    String? reason,
  }) async {
    final updated = row.copyWith(
      status: DeliveryStatus.skipped,
      actualQuantity: 0,
      deliveredAt: null,
    );
    await _persist(updated);
    await _audit.log(
      flatId: row.flatId,
      actor: actor,
      type: AuditChangeType.paused,
      oldValue: '${row.status.name} ${row.actualQuantity}',
      newValue: '${updated.status.name} 0',
      reason: reason,
    );
    return updated;
  }

  Future<DailyDelivery> markPaused(
    DailyDelivery row,
    AppUser actor, {
    String? reason,
  }) async {
    final updated = row.copyWith(
      status: DeliveryStatus.paused,
      actualQuantity: 0,
      deliveredAt: null,
    );
    await _persist(updated);
    await _audit.log(
      flatId: row.flatId,
      actor: actor,
      type: AuditChangeType.paused,
      oldValue: '${row.status.name} ${row.actualQuantity}',
      newValue: '${updated.status.name} 0',
      reason: reason,
    );
    return updated;
  }

  Future<DailyDelivery> markAbsent(
    DailyDelivery row,
    AppUser actor, {
    String? reason,
  }) async {
    final updated = row.copyWith(
      status: DeliveryStatus.milkmanAbsent,
      actualQuantity: 0,
      deliveredAt: null,
    );
    await _persist(updated);
    await _audit.log(
      flatId: row.flatId,
      actor: actor,
      type: AuditChangeType.milkmanAbsenceAdded,
      oldValue: '${row.status.name} ${row.actualQuantity}',
      newValue: '${updated.status.name} 0',
      reason: reason,
    );
    return updated;
  }

  Future<DailyDelivery> markPending(DailyDelivery row, AppUser actor) async {
    final updated = row.copyWith(
      status: DeliveryStatus.pending,
      actualQuantity: 0,
      deliveredAt: null,
    );
    await _persist(updated);
    await _audit.log(
      flatId: row.flatId,
      actor: actor,
      type: AuditChangeType.milkmanAbsenceRemoved,
      oldValue: '${row.status.name} ${row.actualQuantity}',
      newValue: 'pending',
    );
    return updated;
  }

  Future<DailyDelivery> setQuantity(
    DailyDelivery row,
    AppUser actor,
    double qty, {
    String? reason,
  }) async {
    final updated = row.copyWith(
      plannedQuantity: qty,
      actualQuantity:
          row.status == DeliveryStatus.delivered ? qty : row.actualQuantity,
    );
    await _persist(updated);
    await _audit.log(
      flatId: row.flatId,
      actor: actor,
      type: AuditChangeType.quantityChanged,
      oldValue: '${row.plannedQuantity}',
      newValue: '${updated.plannedQuantity}',
      reason: reason,
    );
    return updated;
  }

  Future<void> _persist(DailyDelivery d) async {
    await LocalStore.instance.deliveries.put(d.id, d.toJson());
    await SyncQueue.instance.enqueue('upsert', 'deliveries', d.toJson());
  }

  /// Aggregate monthly bill for a flat across ALL products it subscribes to.
  MonthlySummary summary(String flatId, DateTime month) {
    final flat = _flats.byId(flatId);
    if (flat == null) {
      return MonthlySummary.empty(flatId, AppDates.monthKey(month));
    }
    final prefix = AppDates.monthKey(month);
    final rows = LocalStore.instance.deliveries.values
        .whereType<Map>()
        .map(DailyDelivery.fromJson)
        .where((d) => d.flatId == flatId && d.dateKey.startsWith(prefix))
        .toList();

    double totalAmount = 0;
    int delivered = 0;
    int subscriberPaused = 0;
    int milkmanAbsent = 0;
    final perProduct = <String, _ProductAccumulator>{};

    for (final r in rows) {
      switch (r.status) {
        case DeliveryStatus.delivered:
          final amt = r.actualQuantity * r.unitPrice;
          totalAmount += amt;
          delivered++;
          final acc = perProduct.putIfAbsent(
              r.productId, () => _ProductAccumulator());
          acc.quantity += r.actualQuantity;
          acc.subtotal += amt;
          acc.days++;
          break;
        case DeliveryStatus.paused:
        case DeliveryStatus.skipped:
          subscriberPaused++;
          break;
        case DeliveryStatus.milkmanAbsent:
          milkmanAbsent++;
          break;
        case DeliveryStatus.pending:
          break;
      }
    }

    final products = perProduct.entries
        .map((e) => ProductLine(
              productId: e.key,
              quantity: e.value.quantity,
              subtotal: e.value.subtotal,
              days: e.value.days,
            ))
        .toList();

    return MonthlySummary(
      flatId: flatId,
      monthKey: prefix,
      totalAmount: totalAmount,
      daysSubscriberPaused: subscriberPaused,
      daysMilkmanAbsent: milkmanAbsent,
      daysDelivered: delivered,
      products: products,
      // Legacy fields kept so the old UI compiles during the rollout.
      totalLitres: products
          .where((p) => p.productId.isNotEmpty)
          .fold(0.0, (sum, p) => sum + p.quantity),
      amountDue: totalAmount,
      daysCustom: 0,
      pricePerLitre: flat.pricePerLitre,
    );
  }
}

class _ProductAccumulator {
  double quantity = 0;
  double subtotal = 0;
  int days = 0;
}

class ProductLine {
  ProductLine({
    required this.productId,
    required this.quantity,
    required this.subtotal,
    required this.days,
  });

  final String productId;
  final double quantity;
  final double subtotal;
  final int days;
}

class MonthlySummary {
  MonthlySummary({
    required this.flatId,
    required this.monthKey,
    required this.totalAmount,
    required this.daysSubscriberPaused,
    required this.daysMilkmanAbsent,
    required this.daysDelivered,
    required this.products,
    required this.totalLitres,
    required this.amountDue,
    required this.daysCustom,
    required this.pricePerLitre,
  });

  factory MonthlySummary.empty(String flatId, String monthKey) =>
      MonthlySummary(
        flatId: flatId,
        monthKey: monthKey,
        totalAmount: 0,
        daysSubscriberPaused: 0,
        daysMilkmanAbsent: 0,
        daysDelivered: 0,
        products: const [],
        totalLitres: 0,
        amountDue: 0,
        daysCustom: 0,
        pricePerLitre: 0,
      );

  final String flatId;
  final String monthKey;
  final double totalAmount;
  final int daysSubscriberPaused;
  final int daysMilkmanAbsent;
  final int daysDelivered;
  final List<ProductLine> products;

  // Legacy fields used by the older UI screens; safe to remove once those
  // screens fully migrate.
  final double totalLitres;
  final double amountDue;
  final int daysCustom;
  final double pricePerLitre;
}
