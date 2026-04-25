import 'package:uuid/uuid.dart';

import '../local/local_store.dart';
import '../local/sync_queue.dart';
import '../models/society.dart';

class SocietyRepository {
  static const _uuid = Uuid();

  Stream<List<Society>> watchForMilkman(String milkmanId) async* {
    yield _all(milkmanId);
    yield* LocalStore.instance.societies.watch().map((_) => _all(milkmanId));
  }

  List<Society> _all(String milkmanId) => LocalStore.instance.societies.values
      .whereType<Map>()
      .map(Society.fromJson)
      .where((s) => s.milkmanId == milkmanId)
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  Future<Society> create({
    required String milkmanId,
    required String name,
    required String address,
  }) async {
    final s = Society(
      id: _uuid.v4(),
      milkmanId: milkmanId,
      name: name,
      address: address,
    );
    await LocalStore.instance.societies.put(s.id, s.toJson());
    await SyncQueue.instance.enqueue('upsert', 'societies', s.toJson());
    return s;
  }

  Future<void> delete(String id) async {
    await LocalStore.instance.societies.delete(id);
    await SyncQueue.instance.enqueue('delete', 'societies', {'id': id});
  }

  Society? byId(String id) {
    final raw = LocalStore.instance.societies.get(id);
    if (raw is Map) return Society.fromJson(raw);
    return null;
  }
}
