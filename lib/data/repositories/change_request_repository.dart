import 'package:uuid/uuid.dart';

import '../../core/utils/date_utils.dart';
import '../local/local_store.dart';
import '../local/sync_queue.dart';
import '../models/audit_log.dart';
import '../models/change_request.dart';
import '../models/daily_delivery.dart';
import '../models/user.dart';
import 'audit_repository.dart';
import 'delivery_repository.dart';
import 'flat_repository.dart';

class ChangeRequestRepository {
  ChangeRequestRepository(this._flats, this._deliveries, this._audit);

  final FlatRepository _flats;
  final DeliveryRepository _deliveries;
  final AuditRepository _audit;
  static const _uuid = Uuid();

  Stream<List<ChangeRequest>> watchAllForMilkman(Iterable<String> flatIds) async* {
    final ids = flatIds.toSet();
    yield _all().where((r) => ids.contains(r.flatId)).toList();
    yield* LocalStore.instance.changeRequests.watch().map(
          (_) => _all().where((r) => ids.contains(r.flatId)).toList(),
        );
  }

  Stream<List<ChangeRequest>> watchForFlat(String flatId) async* {
    yield _all().where((r) => r.flatId == flatId).toList();
    yield* LocalStore.instance.changeRequests.watch().map(
          (_) => _all().where((r) => r.flatId == flatId).toList(),
        );
  }

  List<ChangeRequest> _all() => LocalStore.instance.changeRequests.values
      .whereType<Map>()
      .map(ChangeRequest.fromJson)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<ChangeRequest> createPause({
    required String flatId,
    required AppUser actor,
    required DateTime fromDate,
    required DateTime toDate,
    String? note,
  }) async {
    final req = ChangeRequest(
      id: _uuid.v4(),
      flatId: flatId,
      requestedByUserId: actor.id,
      requestedByName: actor.name,
      requestedByPhone: actor.phone,
      type: ChangeRequestType.pause,
      fromDateKey: AppDates.dateKey(fromDate),
      toDateKey: AppDates.dateKey(toDate),
      newQuantity: 0,
      status: ChangeRequestStatus.pending,
      createdAt: DateTime.now(),
      note: note,
    );
    await _persist(req);
    await _audit.log(
      flatId: flatId,
      actor: actor,
      type: AuditChangeType.changeRequestCreated,
      oldValue: '-',
      newValue: 'pause ${req.fromDateKey}→${req.toDateKey}',
      reason: note,
    );
    return req;
  }

  Future<ChangeRequest> createQuantityChange({
    required String flatId,
    required AppUser actor,
    required DateTime fromDate,
    required DateTime toDate,
    required double newQuantity,
    String? note,
  }) async {
    final req = ChangeRequest(
      id: _uuid.v4(),
      flatId: flatId,
      requestedByUserId: actor.id,
      requestedByName: actor.name,
      requestedByPhone: actor.phone,
      type: ChangeRequestType.quantityChange,
      fromDateKey: AppDates.dateKey(fromDate),
      toDateKey: AppDates.dateKey(toDate),
      newQuantity: newQuantity,
      status: ChangeRequestStatus.pending,
      createdAt: DateTime.now(),
      note: note,
    );
    await _persist(req);
    await _audit.log(
      flatId: flatId,
      actor: actor,
      type: AuditChangeType.changeRequestCreated,
      oldValue: '-',
      newValue:
          'qty=${newQuantity}L ${req.fromDateKey}→${req.toDateKey}',
      reason: note,
    );
    return req;
  }

  /// Apply a request to the affected daily delivery rows.
  Future<void> apply(ChangeRequest req, AppUser actor) async {
    final flat = _flats.byId(req.flatId);
    if (flat == null) return;
    final from = AppDates.parseKey(req.fromDateKey);
    final to = AppDates.parseKey(req.toDateKey);
    var cursor = from;
    while (!cursor.isAfter(to)) {
      final row = _deliveries.ensureForToday(flat, when: cursor);
      switch (req.type) {
        case ChangeRequestType.pause:
          await _deliveries.markSkipped(row, actor, reason: 'subscriber pause');
          break;
        case ChangeRequestType.quantityChange:
          await _deliveries.setQuantity(
            row,
            actor,
            req.newQuantity,
            reason: 'subscriber quantity change',
          );
          break;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    final updated = req.copyWith(status: ChangeRequestStatus.applied);
    await _persist(updated);
    await _audit.log(
      flatId: req.flatId,
      actor: actor,
      type: AuditChangeType.changeRequestApplied,
      oldValue: 'pending',
      newValue: 'applied',
    );
  }

  Future<void> _persist(ChangeRequest r) async {
    await LocalStore.instance.changeRequests.put(r.id, r.toJson());
    await SyncQueue.instance.enqueue('upsert', 'change_requests', r.toJson());
  }

  /// Pre-apply pending pause/quantity requests to a fresh delivery row so the
  /// milkman's route already reflects subscriber requests when the day starts.
  DeliveryStatus statusOverrideFor(String flatId, String dateKey) {
    final pending = _all().where((r) =>
        r.flatId == flatId &&
        r.status == ChangeRequestStatus.pending &&
        dateKey.compareTo(r.fromDateKey) >= 0 &&
        dateKey.compareTo(r.toDateKey) <= 0);
    for (final r in pending) {
      if (r.type == ChangeRequestType.pause) return DeliveryStatus.paused;
    }
    return DeliveryStatus.pending;
  }
}
