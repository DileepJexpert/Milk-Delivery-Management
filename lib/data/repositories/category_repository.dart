import 'package:uuid/uuid.dart';

import '../local/local_store.dart';
import '../local/sync_queue.dart';
import '../models/audit_log.dart';
import '../models/category.dart';
import '../models/user.dart';
import 'audit_repository.dart';

class CategoryRepository {
  CategoryRepository(this._audit);

  final AuditRepository _audit;
  static const _uuid = Uuid();

  Stream<List<ProductCategory>> watchAll() async* {
    yield _all();
    yield* LocalStore.instance.categories.watch().map((_) => _all());
  }

  List<ProductCategory> _all() => LocalStore.instance.categories.values
      .whereType<Map>()
      .map(ProductCategory.fromJson)
      .toList()
    ..sort((a, b) {
      final s = a.sortOrder.compareTo(b.sortOrder);
      return s != 0 ? s : a.name.compareTo(b.name);
    });

  List<ProductCategory> all() => _all();

  ProductCategory? byId(String id) {
    final raw = LocalStore.instance.categories.get(id);
    if (raw is Map) return ProductCategory.fromJson(raw);
    return null;
  }

  Future<ProductCategory> create({
    required String name,
    String? icon,
    int sortOrder = 0,
    AppUser? actor,
  }) async {
    final c = ProductCategory(
      id: _uuid.v4(),
      name: name,
      icon: icon,
      sortOrder: sortOrder,
    );
    await _persist(c);
    if (actor != null) {
      await _audit.log(
        flatId: '-',
        actor: actor,
        type: AuditChangeType.categoryAdded,
        oldValue: '-',
        newValue: name,
      );
    }
    return c;
  }

  Future<ProductCategory> update(ProductCategory c, AppUser actor) async {
    final old = byId(c.id);
    await _persist(c);
    await _audit.log(
      flatId: '-',
      actor: actor,
      type: AuditChangeType.categoryUpdated,
      oldValue: old?.name ?? '-',
      newValue: c.name,
    );
    return c;
  }

  Future<void> _persist(ProductCategory c) async {
    await LocalStore.instance.categories.put(c.id, c.toJson());
    await SyncQueue.instance.enqueue('upsert', 'product_categories', c.toJson());
  }
}
