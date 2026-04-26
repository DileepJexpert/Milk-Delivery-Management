import 'package:uuid/uuid.dart';

import '../../core/utils/date_utils.dart';
import '../local/local_store.dart';
import '../local/sync_queue.dart';
import '../models/audit_log.dart';
import '../models/daily_delivery.dart';
import '../models/flat.dart';
import '../models/milkman_absence.dart';
import '../models/society.dart';
import '../models/user.dart';
import 'audit_repository.dart';
import 'delivery_repository.dart';

class AbsenceRepository {
  AbsenceRepository(this._deliveries, this._audit);

  final DeliveryRepository _deliveries;
  final AuditRepository _audit;
  static const _uuid = Uuid();

  Stream<List<MilkmanAbsence>> watchForMilkman(String milkmanId) async* {
    yield _all(milkmanId);
    yield* LocalStore.instance.absences.watch().map((_) => _all(milkmanId));
  }

  List<MilkmanAbsence> _all(String milkmanId) =>
      LocalStore.instance.absences.values
          .whereType<Map>()
          .map(MilkmanAbsence.fromJson)
          .where((a) => a.milkmanId == milkmanId)
          .toList()
        ..sort((a, b) => a.fromDateKey.compareTo(b.fromDateKey));

  /// True if [date] falls within any absence (range or recurring weekday)
  /// owned by [milkmanId].
  bool isAbsentOn(DateTime date, String milkmanId) {
    final key = AppDates.dateKey(date);
    final dow = date.weekday; // 1=Mon..7=Sun
    for (final raw in LocalStore.instance.absences.values.whereType<Map>()) {
      final a = MilkmanAbsence.fromJson(raw);
      if (a.milkmanId != milkmanId) continue;
      if (a.isRecurring) {
        if (a.recurringDayOfWeek == dow) return true;
      } else {
        if (key.compareTo(a.fromDateKey) >= 0 &&
            key.compareTo(a.toDateKey) <= 0) {
          return true;
        }
      }
    }
    return false;
  }

  Iterable<Flat> _flatsForMilkman(String milkmanId) {
    final societyIds = LocalStore.instance.societies.values
        .whereType<Map>()
        .map(Society.fromJson)
        .where((s) => s.milkmanId == milkmanId)
        .map((s) => s.id)
        .toSet();
    return LocalStore.instance.flats.values
        .whereType<Map>()
        .map(Flat.fromJson)
        .where((f) => societyIds.contains(f.societyId));
  }

  Future<MilkmanAbsence> createRange({
    required AppUser milkman,
    required DateTime fromDate,
    required DateTime toDate,
    String? reason,
  }) async {
    final absence = MilkmanAbsence(
      id: _uuid.v4(),
      milkmanId: milkman.id,
      fromDateKey: AppDates.dateKey(fromDate),
      toDateKey: AppDates.dateKey(toDate),
      reason: reason,
      isRecurring: false,
    );
    await _persist(absence);
    await _applyAbsenceToRange(milkman, fromDate, toDate, reason);
    return absence;
  }

  Future<MilkmanAbsence> createRecurring({
    required AppUser milkman,
    required int dayOfWeek, // 1=Mon..7=Sun
    String? reason,
  }) async {
    final today = AppDates.today();
    final absence = MilkmanAbsence(
      id: _uuid.v4(),
      milkmanId: milkman.id,
      fromDateKey: AppDates.dateKey(today),
      toDateKey: AppDates.dateKey(today),
      reason: reason,
      isRecurring: true,
      recurringDayOfWeek: dayOfWeek,
    );
    await _persist(absence);
    // Mark the next 60 days of matching weekdays as absent so existing rows
    // get rewritten and future rows seed correctly.
    for (int i = 0; i < 60; i++) {
      final d = today.add(Duration(days: i));
      if (d.weekday == dayOfWeek) {
        await _applyAbsenceToRange(milkman, d, d, reason);
      }
    }
    return absence;
  }

  /// "I'm off today" — convenience for last-minute absences.
  Future<MilkmanAbsence> createForToday({
    required AppUser milkman,
    String? reason,
  }) {
    final today = AppDates.today();
    return createRange(
      milkman: milkman,
      fromDate: today,
      toDate: today,
      reason: reason,
    );
  }

  Future<void> delete(String absenceId, AppUser milkman) async {
    final raw = LocalStore.instance.absences.get(absenceId);
    if (raw is! Map) return;
    final absence = MilkmanAbsence.fromJson(raw);
    await LocalStore.instance.absences.delete(absenceId);
    await SyncQueue.instance
        .enqueue('delete', 'milkman_absences', {'id': absenceId});

    // Revert any deliveries still flagged as absent within the affected range
    // to "pending" so the milkman can re-mark them.
    final from = AppDates.parseKey(absence.fromDateKey);
    final to = AppDates.parseKey(absence.toDateKey);
    final flats = _flatsForMilkman(milkman.id).toList();
    if (absence.isRecurring) {
      // Best-effort: revert next 60 days of that weekday.
      for (int i = 0; i < 60; i++) {
        final d = AppDates.today().add(Duration(days: i));
        if (d.weekday == absence.recurringDayOfWeek) {
          await _revertAbsenceForDate(flats, milkman, d);
        }
      }
    } else {
      var cursor = from;
      while (!cursor.isAfter(to)) {
        await _revertAbsenceForDate(flats, milkman, cursor);
        cursor = cursor.add(const Duration(days: 1));
      }
    }

    // Audit on each flat so the change is visible per-flat.
    for (final f in flats) {
      await _audit.log(
        flatId: f.id,
        actor: milkman,
        type: AuditChangeType.milkmanAbsenceRemoved,
        oldValue:
            'absent ${absence.fromDateKey}→${absence.toDateKey}${absence.isRecurring ? ' (weekly)' : ''}',
        newValue: '-',
        reason: absence.reason,
      );
    }
  }

  Future<void> markNotified(String absenceId) async {
    final raw = LocalStore.instance.absences.get(absenceId);
    if (raw is! Map) return;
    final updated =
        MilkmanAbsence.fromJson(raw).copyWith(notifiedAt: DateTime.now());
    await _persist(updated);
  }

  Future<void> _applyAbsenceToRange(
    AppUser milkman,
    DateTime from,
    DateTime to,
    String? reason,
  ) async {
    final flats = _flatsForMilkman(milkman.id).toList();
    var cursor = from;
    while (!cursor.isAfter(to)) {
      for (final f in flats) {
        final row = _deliveries.ensureForToday(f, when: cursor);
        // Don't clobber an already-delivered row; that's data the milkman
        // explicitly recorded. markAbsent already writes a per-flat audit
        // entry, so the absence is fully traceable from each flat's history.
        if (row.status != DeliveryStatus.delivered) {
          await _deliveries.markAbsent(row, milkman, reason: reason);
        }
      }
      cursor = cursor.add(const Duration(days: 1));
    }
  }

  Future<void> _revertAbsenceForDate(
    List<Flat> flats,
    AppUser milkman,
    DateTime date,
  ) async {
    final key = AppDates.dateKey(date);
    for (final f in flats) {
      final raw = LocalStore.instance.deliveries.values
          .whereType<Map>()
          .map(DailyDelivery.fromJson)
          .where((d) => d.flatId == f.id && d.dateKey == key)
          .toList();
      for (final row in raw) {
        if (row.status == DeliveryStatus.milkmanAbsent) {
          await _deliveries.markPending(row, milkman);
        }
      }
    }
  }

  Future<void> _persist(MilkmanAbsence a) async {
    await LocalStore.instance.absences.put(a.id, a.toJson());
    await SyncQueue.instance
        .enqueue('upsert', 'milkman_absences', a.toJson());
  }
}
