import 'package:uuid/uuid.dart';

import '../local/local_store.dart';
import '../local/sync_queue.dart';
import '../models/flat.dart';

class FlatRepository {
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
    await LocalStore.instance.flats.put(f.id, f.toJson());
    await SyncQueue.instance.enqueue('upsert', 'flats', f.toJson());
    return f;
  }

  Future<Flat> update(Flat f) async {
    await LocalStore.instance.flats.put(f.id, f.toJson());
    await SyncQueue.instance.enqueue('upsert', 'flats', f.toJson());
    return f;
  }

  Future<void> delete(String id) async {
    await LocalStore.instance.flats.delete(id);
    await SyncQueue.instance.enqueue('delete', 'flats', {'id': id});
  }
}
