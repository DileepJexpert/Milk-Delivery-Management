import 'package:uuid/uuid.dart';

import '../../core/utils/date_utils.dart';
import '../local/local_store.dart';
import '../local/sync_queue.dart';
import '../models/audit_log.dart';
import '../models/daily_delivery.dart';
import '../models/flat.dart' show Flat, FlatStatus;
import '../models/user.dart';
import 'audit_repository.dart';
import 'flat_repository.dart';

class DeliveryRepository {
  DeliveryRepository(this._flats, this._audit);

  final FlatRepository _flats;
  final AuditRepository _audit;
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

  /// Returns the existing delivery for [flatId]/[dateKey], or seeds a new row.
  /// Stopped flats get a paused row without persisting (they're not on route).
  /// Flat-level paused flats get a persisted paused row.
  DailyDelivery ensureForToday(Flat flat, {DateTime? when}) {
    final date = when ?? AppDates.today();
    final key = AppDates.dateKey(date);
    final existing = LocalStore.instance.deliveries.values
        .whereType<Map>()
        .map(DailyDelivery.fromJson)
        .where((d) => d.flatId == flat.id && d.dateKey == key)
        .toList();
    if (existing.isNotEmpty) return existing.first;
    final status = flat.status == FlatStatus.active
        ? DeliveryStatus.pending
        : DeliveryStatus.paused;
    final fresh = DailyDelivery(
      id: _uuid.v4(),
      flatId: flat.id,
      dateKey: key,
      plannedQuantity: flat.defaultQuantity,
      actualQuantity: 0,
      status: status,
    );
    // Don't persist a delivery row for permanently stopped flats.
    if (flat.status != FlatStatus.stopped) {
      LocalStore.instance.deliveries.put(fresh.id, fresh.toJson());
    }
    return fresh;
  }

  /// Ensure today's delivery rows exist for the entire route.
  /// Stopped flats are excluded entirely.
  Future<List<DailyDelivery>> ensureRouteForToday(List<Flat> flats) async {
    final out = <DailyDelivery>[];
    for (final f in flats) {
      if (f.status == FlatStatus.stopped) continue;
      out.add(ensureForToday(f));
    }
    return out;
  }

  Future<DailyDelivery> markDelivered(
    DailyDelivery row,
    AppUser actor, {
    double? quantity,
    String? reason,
  }) async {
    final qty = quantity ?? row.plannedQuantity;
    final updated = row.copyWith(
      status: DeliveryStatus.delivered,
      actualQuantity: qty,
      deliveredAt: DateTime.now(),
    );
    await _persist(updated);
    await _audit.log(
      flatId: row.flatId,
      actor: actor,
      type: AuditChangeType.deliveryMarked,
      oldValue: '${row.status.name} ${row.actualQuantity}L',
      newValue: '${updated.status.name} ${updated.actualQuantity}L',
      reason: reason,
    );
    return updated;
  }

  /// Milkman skipped this flat during the round (one-off, neither subscriber
  /// pause nor planned absence).
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
      oldValue: '${row.status.name} ${row.actualQuantity}L',
      newValue: '${updated.status.name} 0L',
      reason: reason,
    );
    return updated;
  }

  /// Subscriber asked to pause delivery for this date.
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
      oldValue: '${row.status.name} ${row.actualQuantity}L',
      newValue: '${updated.status.name} 0L',
      reason: reason,
    );
    return updated;
  }

  /// Milkman is off (sick / holiday / weekly off). These days do NOT count
  /// toward the bill.
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
      oldValue: '${row.status.name} ${row.actualQuantity}L',
      newValue: '${updated.status.name} 0L',
      reason: reason,
    );
    return updated;
  }

  /// Reset a delivery row to pending (used when an absence is cancelled).
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
      oldValue: '${row.status.name} ${row.actualQuantity}L',
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
      oldValue: '${row.plannedQuantity}L',
      newValue: '${updated.plannedQuantity}L',
      reason: reason,
    );
    return updated;
  }

  Future<void> _persist(DailyDelivery d) async {
    await LocalStore.instance.deliveries.put(d.id, d.toJson());
    await SyncQueue.instance.enqueue('upsert', 'deliveries', d.toJson());
  }

  /// Aggregate one flat's monthly numbers, broken into the three billing
  /// buckets the spec asks for.
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
    double totalLitres = 0;
    int delivered = 0;
    int custom = 0;
    int subscriberPaused = 0;
    int milkmanAbsent = 0;
    for (final r in rows) {
      switch (r.status) {
        case DeliveryStatus.delivered:
          totalLitres += r.actualQuantity;
          delivered++;
          if (r.actualQuantity != flat.defaultQuantity) custom++;
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
    return MonthlySummary(
      flatId: flatId,
      monthKey: prefix,
      totalLitres: totalLitres,
      daysSubscriberPaused: subscriberPaused,
      daysMilkmanAbsent: milkmanAbsent,
      daysCustom: custom,
      daysDelivered: delivered,
      amountDue: totalLitres * flat.pricePerLitre,
      pricePerLitre: flat.pricePerLitre,
    );
  }
}

class MonthlySummary {
  MonthlySummary({
    required this.flatId,
    required this.monthKey,
    required this.totalLitres,
    required this.daysSubscriberPaused,
    required this.daysMilkmanAbsent,
    required this.daysCustom,
    required this.daysDelivered,
    required this.amountDue,
    required this.pricePerLitre,
  });

  factory MonthlySummary.empty(String flatId, String monthKey) =>
      MonthlySummary(
        flatId: flatId,
        monthKey: monthKey,
        totalLitres: 0,
        daysSubscriberPaused: 0,
        daysMilkmanAbsent: 0,
        daysCustom: 0,
        daysDelivered: 0,
        amountDue: 0,
        pricePerLitre: 0,
      );

  final String flatId;
  final String monthKey;
  final double totalLitres;
  /// Days where the subscriber paused (or milkman one-off skipped) — not billable.
  final int daysSubscriberPaused;
  /// Days where the milkman was off entirely — not billable.
  final int daysMilkmanAbsent;
  final int daysCustom;
  final int daysDelivered;
  final double amountDue;
  final double pricePerLitre;
}
