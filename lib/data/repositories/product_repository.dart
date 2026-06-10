import 'package:uuid/uuid.dart';

import '../local/local_store.dart';
import '../local/sync_queue.dart';
import '../models/audit_log.dart';
import '../models/product.dart';
import '../models/user.dart';
import 'audit_repository.dart';

class ProductRepository {
  ProductRepository(this._audit);

  final AuditRepository _audit;
  static const _uuid = Uuid();

  Stream<List<Product>> watchAll() async* {
    yield _all();
    yield* LocalStore.instance.products.watch().map((_) => _all());
  }

  Stream<List<Product>> watchActive() async* {
    yield _all().where((p) => p.active).toList();
    yield* LocalStore.instance.products
        .watch()
        .map((_) => _all().where((p) => p.active).toList());
  }

  List<Product> _all() => LocalStore.instance.products.values
      .whereType<Map>()
      .map(Product.fromJson)
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  List<Product> all() => _all();

  Product? byId(String id) {
    final raw = LocalStore.instance.products.get(id);
    if (raw is Map) return Product.fromJson(raw);
    return null;
  }

  /// Lookup product by name — used by migration to find the seeded "Cow Milk".
  Product? byName(String name) {
    for (final raw in LocalStore.instance.products.values.whereType<Map>()) {
      final p = Product.fromJson(raw);
      if (p.name.toLowerCase() == name.toLowerCase()) return p;
    }
    return null;
  }

  Future<Product> create({
    required String categoryId,
    required String name,
    required ProductUnit unit,
    required double defaultPrice,
    bool active = true,
    AppUser? actor,
  }) async {
    final p = Product(
      id: _uuid.v4(),
      categoryId: categoryId,
      name: name,
      unit: unit,
      defaultPrice: defaultPrice,
      active: active,
    );
    await _persist(p);
    if (actor != null) {
      await _audit.log(
        flatId: '-',
        actor: actor,
        type: AuditChangeType.productAdded,
        oldValue: '-',
        newValue: '$name · ${unit.name} · ₹$defaultPrice',
      );
    }
    return p;
  }

  Future<Product> update(Product p, AppUser actor) async {
    final old = byId(p.id);
    await _persist(p);
    await _audit.log(
      flatId: '-',
      actor: actor,
      type: AuditChangeType.productUpdated,
      oldValue: old == null
          ? '-'
          : '${old.name} · ${old.unit.name} · ₹${old.defaultPrice} · ${old.active ? "active" : "inactive"}',
      newValue:
          '${p.name} · ${p.unit.name} · ₹${p.defaultPrice} · ${p.active ? "active" : "inactive"}',
    );
    return p;
  }

  Future<void> _persist(Product p) async {
    await LocalStore.instance.products.put(p.id, p.toJson());
    await SyncQueue.instance.enqueue('upsert', 'products', p.toJson());
  }
}
