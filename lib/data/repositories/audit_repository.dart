import 'package:uuid/uuid.dart';

import '../local/local_store.dart';
import '../local/sync_queue.dart';
import '../models/audit_log.dart';
import '../models/user.dart';

class AuditRepository {
  static const _uuid = Uuid();

  Stream<List<AuditLog>> watchForFlat(String flatId) async* {
    yield _allForFlat(flatId);
    yield* LocalStore.instance.auditLogs.watch().map((_) => _allForFlat(flatId));
  }

  List<AuditLog> _allForFlat(String flatId) =>
      LocalStore.instance.auditLogs.values
          .whereType<Map>()
          .map(AuditLog.fromJson)
          .where((a) => a.flatId == flatId)
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  Future<AuditLog> log({
    required String flatId,
    required AppUser actor,
    required AuditChangeType type,
    required String oldValue,
    required String newValue,
    String? reason,
  }) async {
    final entry = AuditLog(
      id: _uuid.v4(),
      flatId: flatId,
      changedByUserId: actor.id,
      changedByName: actor.name,
      changedByPhone: actor.phone,
      changeType: type,
      oldValue: oldValue,
      newValue: newValue,
      timestamp: DateTime.now(),
      reason: reason,
    );
    await LocalStore.instance.auditLogs.put(entry.id, entry.toJson());
    await SyncQueue.instance.enqueue('upsert', 'audit_logs', entry.toJson());
    return entry;
  }
}
