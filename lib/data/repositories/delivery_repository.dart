import 'package:uuid/uuid.dart';

import '../../core/utils/date_utils.dart';
import '../../core/utils/indian_holidays.dart';
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
  /// the active subscription if it doesn't exist yet. Respects the
  /// subscription's schedule pattern and the flat's vacation range — if the
  /// product isn't scheduled today, returns a paused row without persisting.
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

    final scheduled = sub.isActiveOn(date);
    final onVacation = flat.isOnVacation(key);
    final onFestival =
        flat.pauseOnFestivals && IndianHolidays.isHoliday(key);
    DeliveryStatus initialStatus;
    if (flat.status != FlatStatus.active ||
        onVacation ||
        onFestival ||
        !scheduled) {
      initialStatus = DeliveryStatus.paused;
    } else {
      initialStatus = DeliveryStatus.pending;
    }
    final fresh = DailyDelivery(
      id: _uuid.v4(),
      flatId: flat.id,
      productId: sub.productId,
      dateKey: key,
      plannedQuantity: scheduled ? sub.quantity : 0,
      actualQuantity: 0,
      unitPrice: sub.unitPrice,
      status: initialStatus,
    );
    // Don't persist non-billable / off-schedule rows — keeps the box small
    // and keeps Today's Route + audit log clean.
    final persist = flat.status != FlatStatus.stopped &&
        !onVacation &&
        !onFestival &&
        scheduled;
    if (persist) {
      LocalStore.instance.deliveries.put(fresh.id, fresh.toJson());
    }
    return fresh;
  }

  /// For every active subscription on every (non-stopped) flat, ensure a
  /// delivery row exists for today — skipping subscriptions that aren't
  /// scheduled today (alternate days, weekday-only, etc.) and flats on
  /// vacation.
  Future<List<DailyDelivery>> ensureRouteForToday(List<Flat> flats) async {
    final today = AppDates.today();
    final todayKey = AppDates.dateKey(today);
    final out = <DailyDelivery>[];
    final isFestival = IndianHolidays.isHoliday(todayKey);
    for (final f in flats) {
      if (f.status == FlatStatus.stopped) continue;
      if (f.isOnVacation(todayKey)) continue;
      if (f.pauseOnFestivals && isFestival) continue;
      final subs = _subscriptions.activeForFlat(f.id);
      for (final s in subs) {
        if (!s.isActiveOn(today)) continue;
        out.add(ensureForSubscription(f, s));
      }
    }
    // One-time rows persisted earlier (createOneTime) will surface through
    // watchForDate alongside the scheduled rows above.
    return out;
  }

  /// Creates a standalone delivery row not tied to a recurring subscription —
  /// e.g. "1 extra L tomorrow". Marked `isOneTime` so the route can tag it.
  Future<DailyDelivery> createOneTime({
    required Flat flat,
    required String productId,
    required double quantity,
    required double unitPrice,
    required DateTime when,
    required AppUser actor,
  }) async {
    final key = AppDates.dateKey(when);
    final row = DailyDelivery(
      id: _uuid.v4(),
      flatId: flat.id,
      productId: productId,
      dateKey: key,
      plannedQuantity: quantity,
      actualQuantity: 0,
      unitPrice: unitPrice,
      status: DeliveryStatus.pending,
      isOneTime: true,
    );
    await _persist(row);
    await _audit.log(
      flatId: flat.id,
      actor: actor,
      type: AuditChangeType.oneTimeOrder,
      oldValue: '-',
      newValue: '$quantity x $productId on $key',
    );
    return row;
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
    // Auto-debit for prepaid flats. We debit the actual delivered quantity
    // (not the planned), so the customer is never overcharged. The
    // short-delivery auto-credit lives in setQuantity below, which fires when
    // an already-delivered row is later corrected.
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
    final wasDelivered = row.status == DeliveryStatus.delivered;
    final oldActual = row.actualQuantity;
    final updated = row.copyWith(
      plannedQuantity: qty,
      actualQuantity: wasDelivered ? qty : row.actualQuantity,
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
    // Short-delivery auto-credit (or top-up debit): if we corrected an
    // already-delivered row up/down, settle the wallet difference for prepaid
    // flats so the customer never has to ask.
    if (wasDelivered && updated.unitPrice > 0) {
      final flat = _flats.byId(row.flatId);
      if (flat != null && flat.billingMode == BillingMode.prepaid) {
        final delta = qty - oldActual;
        if (delta < 0) {
          await _wallet.refund(
            flat,
            actor,
            -delta * updated.unitPrice,
            relatedDeliveryId: updated.id,
            reason: 'short-delivery auto-credit ($oldActual→$qty)',
          );
        } else if (delta > 0) {
          await _wallet.debit(
            flat,
            actor,
            delta * updated.unitPrice,
            relatedDeliveryId: updated.id,
            reason: 'qty correction debit ($oldActual→$qty)',
          );
        }
      }
    }
    return updated;
  }

  /// Aggregate stats for [date] across all flats — used by the milkman's
  /// daily revenue dashboard. Counts delivered/skipped, sums revenue, and
  /// breaks down collected wallet credits by reason keyword.
  DailyStats dailyStats(DateTime date) {
    final key = AppDates.dateKey(date);
    final rows = LocalStore.instance.deliveries.values
        .whereType<Map>()
        .map(DailyDelivery.fromJson)
        .where((d) => d.dateKey == key)
        .toList();
    int delivered = 0, skipped = 0;
    double revenue = 0;
    for (final r in rows) {
      switch (r.status) {
        case DeliveryStatus.delivered:
          delivered++;
          revenue += r.actualQuantity * r.unitPrice;
          break;
        case DeliveryStatus.paused:
        case DeliveryStatus.skipped:
          skipped++;
          break;
        case DeliveryStatus.milkmanAbsent:
        case DeliveryStatus.pending:
          break;
      }
    }

    // Wallet collections today, bucketed by payment method captured in the
    // reason string ("cash payment", "upi payment", "bank payment").
    final txnsBox = LocalStore.instance.walletTxns;
    double cash = 0, upi = 0, bank = 0;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    for (final raw in txnsBox.values.whereType<Map>()) {
      final ts = raw['timestamp'];
      if (ts is! String) continue;
      final t = DateTime.tryParse(ts);
      if (t == null || t.isBefore(startOfDay) || !t.isBefore(endOfDay)) {
        continue;
      }
      final type = raw['type'];
      if (type != 'topup') continue;
      final amount = (raw['amount'] as num?)?.toDouble() ?? 0;
      final reason = (raw['reason'] as String? ?? '').toLowerCase();
      if (reason.contains('cash')) {
        cash += amount;
      } else if (reason.contains('upi')) {
        upi += amount;
      } else if (reason.contains('bank')) {
        bank += amount;
      } else {
        cash += amount;
      }
    }

    // Outstanding dues = negative wallet balances across all flats. Wallet
    // credits held = positive balances (money customers prepaid that we owe
    // back as service).
    double dues = 0, credits = 0;
    for (final raw in LocalStore.instance.flats.values.whereType<Map>()) {
      final f = Flat.fromJson(raw);
      if (f.walletBalance < 0) {
        dues += -f.walletBalance;
      } else {
        credits += f.walletBalance;
      }
    }

    return DailyStats(
      dateKey: key,
      delivered: delivered,
      skipped: skipped,
      revenue: revenue,
      cashIn: cash,
      upiIn: upi,
      bankIn: bank,
      duesOutstanding: dues,
      walletCreditsHeld: credits,
    );
  }

  /// Per-product quantity totals needed to fulfil [date] across all flats.
  /// Skips paused / skipped / absent rows.
  Map<String, double> inventoryFor(DateTime date) {
    final key = AppDates.dateKey(date);
    final out = <String, double>{};
    for (final raw in LocalStore.instance.deliveries.values.whereType<Map>()) {
      final d = DailyDelivery.fromJson(raw);
      if (d.dateKey != key) continue;
      if (d.status == DeliveryStatus.paused ||
          d.status == DeliveryStatus.skipped ||
          d.status == DeliveryStatus.milkmanAbsent) {
        continue;
      }
      out[d.productId] = (out[d.productId] ?? 0) + d.plannedQuantity;
    }
    return out;
  }

  /// Returns the last [count] monthly summaries for a flat, oldest first.
  /// Useful for the subscriber's spend tracker chart.
  List<MonthlySummary> recentMonths(String flatId, int count, DateTime anchor) {
    final out = <MonthlySummary>[];
    for (int i = count - 1; i >= 0; i--) {
      final m = DateTime(anchor.year, anchor.month - i, 1);
      out.add(summary(flatId, m));
    }
    return out;
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

class DailyStats {
  DailyStats({
    required this.dateKey,
    required this.delivered,
    required this.skipped,
    required this.revenue,
    required this.cashIn,
    required this.upiIn,
    required this.bankIn,
    required this.duesOutstanding,
    required this.walletCreditsHeld,
  });

  final String dateKey;
  final int delivered;
  final int skipped;
  final double revenue;
  final double cashIn;
  final double upiIn;
  final double bankIn;
  final double duesOutstanding;
  final double walletCreditsHeld;

  double get collectedTotal => cashIn + upiIn + bankIn;
}
