import 'package:uuid/uuid.dart';

import '../local/local_store.dart';
import '../local/sync_queue.dart';
import '../models/audit_log.dart';
import '../models/subscription.dart';
import '../models/user.dart';
import 'audit_repository.dart';

class SubscriptionRepository {
  SubscriptionRepository(this._audit);

  final AuditRepository _audit;
  static const _uuid = Uuid();

  Stream<List<Subscription>> watchAll() async* {
    yield _all();
    yield* LocalStore.instance.subscriptions.watch().map((_) => _all());
  }

  Stream<List<Subscription>> watchForFlat(String flatId) async* {
    yield _all().where((s) => s.flatId == flatId).toList();
    yield* LocalStore.instance.subscriptions
        .watch()
        .map((_) => _all().where((s) => s.flatId == flatId).toList());
  }

  List<Subscription> _all() => LocalStore.instance.subscriptions.values
      .whereType<Map>()
      .map(Subscription.fromJson)
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  List<Subscription> all() => _all();

  List<Subscription> activeForFlat(String flatId) => _all()
      .where(
          (s) => s.flatId == flatId && s.status == SubscriptionStatus.active)
      .toList();

  Subscription? byId(String id) {
    final raw = LocalStore.instance.subscriptions.get(id);
    if (raw is Map) return Subscription.fromJson(raw);
    return null;
  }

  Future<Subscription> create({
    required String flatId,
    required String productId,
    required double quantity,
    required double unitPrice,
    SchedulePattern pattern = SchedulePattern.daily,
    List<int> weekDays = const [1, 2, 3, 4, 5, 6, 7],
    AppUser? actor,
  }) async {
    final s = Subscription(
      id: _uuid.v4(),
      flatId: flatId,
      productId: productId,
      quantity: quantity,
      unitPrice: unitPrice,
      status: SubscriptionStatus.active,
      createdAt: DateTime.now(),
      pattern: pattern,
      weekDays: weekDays,
    );
    await _persist(s);
    if (actor != null) {
      await _audit.log(
        flatId: flatId,
        actor: actor,
        type: AuditChangeType.subscriptionAdded,
        oldValue: '-',
        newValue:
            'product=$productId qty=$quantity @ ₹$unitPrice · ${pattern.name}',
      );
    }
    return s;
  }

  Future<Subscription> update(
    Subscription s,
    AppUser actor, {
    double? quantity,
    double? unitPrice,
    SchedulePattern? pattern,
    List<int>? weekDays,
  }) async {
    final updated = s.copyWith(
      quantity: quantity,
      unitPrice: unitPrice,
      pattern: pattern,
      weekDays: weekDays,
    );
    await _persist(updated);
    await _audit.log(
      flatId: s.flatId,
      actor: actor,
      type: AuditChangeType.subscriptionUpdated,
      oldValue: 'qty=${s.quantity} @ ₹${s.unitPrice} · ${s.pattern.name}',
      newValue:
          'qty=${updated.quantity} @ ₹${updated.unitPrice} · ${updated.pattern.name}',
    );
    return updated;
  }

  Future<Subscription> stop(Subscription s, AppUser actor) async {
    final updated = s.copyWith(status: SubscriptionStatus.stopped);
    await _persist(updated);
    await _audit.log(
      flatId: s.flatId,
      actor: actor,
      type: AuditChangeType.subscriptionStopped,
      oldValue: s.status.name,
      newValue: SubscriptionStatus.stopped.name,
    );
    return updated;
  }

  Future<Subscription> reactivate(Subscription s, AppUser actor) async {
    final updated = s.copyWith(status: SubscriptionStatus.active);
    await _persist(updated);
    await _audit.log(
      flatId: s.flatId,
      actor: actor,
      type: AuditChangeType.subscriptionResumed,
      oldValue: s.status.name,
      newValue: SubscriptionStatus.active.name,
    );
    return updated;
  }

  Future<void> _persist(Subscription s) async {
    await LocalStore.instance.subscriptions.put(s.id, s.toJson());
    await SyncQueue.instance.enqueue('upsert', 'subscriptions', s.toJson());
  }
}
