import 'package:uuid/uuid.dart';

import 'local_store.dart';

/// Operations queued while offline. The remote sync service drains this queue
/// when connectivity returns; entries are retried on each connection event.
class SyncQueue {
  SyncQueue._();
  static final SyncQueue instance = SyncQueue._();

  static const _uuid = Uuid();

  Future<void> enqueue(String op, String collection, Map data) async {
    final id = _uuid.v4();
    await LocalStore.instance.syncQueue.put(id, {
      'id': id,
      'op': op,
      'collection': collection,
      'data': Map<String, dynamic>.from(data),
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Iterable<Map> pending() => LocalStore.instance.syncQueue.values
      .whereType<Map>()
      .toList(growable: false);

  Future<void> ack(String id) => LocalStore.instance.syncQueue.delete(id);
}
