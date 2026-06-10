import 'package:uuid/uuid.dart';

import '../local/local_store.dart';
import '../local/sync_queue.dart';
import '../models/audit_log.dart';
import '../models/flat.dart' show Flat, FlatStatus, BillingMode;
import '../models/user.dart';
import 'audit_repository.dart';

class FlatRepository {
  FlatRepository(this._audit);

  final AuditRepository _audit;
  static const _uuid = Uuid();

  Stream<List<Flat>> watchForSociety(String societyId) async* {
    yield _all().where((f) => f.societyId == societyId).toList();
    yield* LocalStore.instance.flats.watch().map(
          (_) => _all().where((f) => f.societyId == societyId).toList(),
        );
  }

  Stream<List<Flat>> watchAllForMilkman(Iterable<String> societyIds) async* {
    final ids = societyIds.toSet();
    yield _all().where((f) => ids.contains(f.societyId)).toList();
    yield* LocalStore.instance.flats.watch().map(
          (_) => _all().where((f) => ids.contains(f.societyId)).toList(),
        );
  }

  List<Flat> _all() => LocalStore.instance.flats.values
      .whereType<Map>()
      .map(Flat.fromJson)
      .toList()
    ..sort((a, b) => a.flatNumber.compareTo(b.flatNumber));

  Flat? byId(String id) {
    final raw = LocalStore.instance.flats.get(id);
    if (raw is Map) return Flat.fromJson(raw);
    return null;
  }

  Flat? byPhone(String phone) {
    final cleaned = _digits(phone);
    for (final raw in LocalStore.instance.flats.values.whereType<Map>()) {
      final f = Flat.fromJson(raw);
      if (_digits(f.ownerPhone) == cleaned) return f;
    }
    return null;
  }

  String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');

  Future<Flat> create({
    required String societyId,
    required String flatNumber,
    required String ownerName,
    required String ownerPhone,
    required bool hasApp,
    required double defaultQuantity,
    required double pricePerLitre,
    AppUser? actor,
  }) async {
    final f = Flat(
      id: _uuid.v4(),
      societyId: societyId,
      flatNumber: flatNumber,
      ownerName: ownerName,
      ownerPhone: ownerPhone,
      hasApp: hasApp,
      defaultQuantity: defaultQuantity,
      pricePerLitre: pricePerLitre,
    );
    await _persist(f);
    if (actor != null) {
      await _audit.log(
        flatId: f.id,
        actor: actor,
        type: AuditChangeType.flatCreated,
        oldValue: '-',
        newValue: '$flatNumber · $ownerName · $ownerPhone',
      );
    }
    return f;
  }

  Future<Flat> update(Flat f) async {
    await _persist(f);
    return f;
  }

  Future<Flat> editFlat(
    Flat flat,
    AppUser actor, {
    String? flatNumber,
    String? ownerName,
    String? ownerPhone,
    bool? hasApp,
    double? defaultQuantity,
    double? pricePerLitre,
  }) async {
    final updated = flat.copyWith(
      flatNumber: flatNumber,
      ownerName: ownerName,
      ownerPhone: ownerPhone,
      hasApp: hasApp,
      defaultQuantity: defaultQuantity,
      pricePerLitre: pricePerLitre,
    );
    await _persist(updated);
    await _audit.log(
      flatId: flat.id,
      actor: actor,
      type: AuditChangeType.flatUpdated,
      oldValue:
          '${flat.ownerName}·${flat.ownerPhone}·${flat.defaultQuantity}L·₹${flat.pricePerLitre}/L',
      newValue:
          '${updated.ownerName}·${updated.ownerPhone}·${updated.defaultQuantity}L·₹${updated.pricePerLitre}/L',
    );
    return updated;
  }

  Future<Flat> pauseFlat(Flat flat, AppUser actor, {String? reason}) async {
    final updated = flat.copyWith(status: FlatStatus.paused);
    await _persist(updated);
    await _audit.log(
      flatId: flat.id,
      actor: actor,
      type: AuditChangeType.flatPaused,
      oldValue: flat.status.name,
      newValue: FlatStatus.paused.name,
      reason: reason,
    );
    return updated;
  }

  Future<Flat> resumeFlat(Flat flat, AppUser actor, {String? reason}) async {
    final updated = flat.copyWith(status: FlatStatus.active);
    await _persist(updated);
    await _audit.log(
      flatId: flat.id,
      actor: actor,
      type: AuditChangeType.flatResumed,
      oldValue: flat.status.name,
      newValue: FlatStatus.active.name,
      reason: reason,
    );
    return updated;
  }

  Future<Flat> setBillingMode(
    Flat flat,
    AppUser actor,
    BillingMode mode,
  ) async {
    if (flat.billingMode == mode) return flat;
    final updated = flat.copyWith(billingMode: mode);
    await _persist(updated);
    await _audit.log(
      flatId: flat.id,
      actor: actor,
      type: AuditChangeType.billingModeChanged,
      oldValue: flat.billingMode.name,
      newValue: mode.name,
    );
    return updated;
  }

  Future<Flat> stopFlat(Flat flat, AppUser actor, {String? reason}) async {
    final updated = flat.copyWith(status: FlatStatus.stopped);
    await _persist(updated);
    await _audit.log(
      flatId: flat.id,
      actor: actor,
      type: AuditChangeType.flatStopped,
      oldValue: flat.status.name,
      newValue: FlatStatus.stopped.name,
      reason: reason,
    );
    return updated;
  }

  Future<void> delete(String id) async {
    await LocalStore.instance.flats.delete(id);
    await SyncQueue.instance.enqueue('delete', 'flats', {'id': id});
  }

  Future<void> _persist(Flat f) async {
    await LocalStore.instance.flats.put(f.id, f.toJson());
    await SyncQueue.instance.enqueue('upsert', 'flats', f.toJson());
  }
}
