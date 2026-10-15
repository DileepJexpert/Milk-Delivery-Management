import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../data/models/category.dart';
import '../../../data/models/product.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../auth/session_controller.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('catalog')),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: t.t('products')),
            Tab(text: t.t('categories')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_ProductsTab(), _CategoriesTab()],
      ),
    );
  }
}

// ───────────────────────────── Products tab ─────────────────────────────

class _ProductsTab extends ConsumerWidget {
  const _ProductsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final productsAsync = ref.watch(productsProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];

    return Stack(
      children: [
        productsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (rows) {
            if (rows.isEmpty) {
              return Center(child: Text(t.t('no_products')));
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (_, i) {
                final p = rows[i];
                final cat = categories.firstWhere(
                  (c) => c.id == p.categoryId,
                  orElse: () => ProductCategory(id: '-', name: '—'),
                );
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: p.active
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Colors.grey.shade300,
                      child: Icon(
                        p.active ? Icons.inventory_2 : Icons.archive,
                        color: p.active
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Colors.grey.shade700,
                      ),
                    ),
                    title: Text(
                      p.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        decoration:
                            p.active ? null : TextDecoration.lineThrough,
                      ),
                    ),
                    subtitle: Text(
                      '${cat.name} · ${p.unit.short} · ₹${p.defaultPrice.toStringAsFixed(2)} / ${p.unit.short}',
                    ),
                    trailing: const Icon(Icons.edit),
                    onTap: () => _editProduct(context, ref, p),
                  ),
                );
              },
            );
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: categories.isEmpty
                ? null
                : () => _editProduct(context, ref, null),
            icon: const Icon(Icons.add),
            label: Text(t.t('add_product')),
          ),
        ),
      ],
    );
  }

  Future<void> _editProduct(
      BuildContext context, WidgetRef ref, Product? existing) async {
    final t = AppLocalizations.of(context);
    final categories = ref.read(categoriesProvider).valueOrNull ?? const [];
    if (categories.isEmpty) return;

    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(
        text: existing?.defaultPrice.toString() ?? '');
    String categoryId = existing?.categoryId ?? categories.first.id;
    ProductUnit unit = existing?.unit ?? ProductUnit.litre;
    bool active = existing?.active ?? true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title:
              Text(existing == null ? t.t('add_product') : t.t('edit_product')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: InputDecoration(labelText: t.t('product_name')),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: categoryId,
                  decoration: InputDecoration(labelText: t.t('category')),
                  items: categories
                      .map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setInner(() => categoryId = v);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ProductUnit>(
                  value: unit,
                  decoration: InputDecoration(labelText: t.t('unit')),
                  items: ProductUnit.values
                      .map((u) => DropdownMenuItem(
                            value: u,
                            child: Text(_unitLabel(u, t)),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setInner(() => unit = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: t.t('default_price')),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t.t('active')),
                  value: active,
                  onChanged: (v) => setInner(() => active = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(t.t('cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(t.t('save'))),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final name = nameCtrl.text.trim();
    final price = double.tryParse(priceCtrl.text);
    if (name.isEmpty || price == null) return;
    final actor = ref.read(sessionControllerProvider).user!;
    final repo = ref.read(productRepositoryProvider);
    if (existing == null) {
      await repo.create(
        categoryId: categoryId,
        name: name,
        unit: unit,
        defaultPrice: price,
        active: active,
        actor: actor,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.t('product_added'))),
        );
      }
    } else {
      await repo.update(
        existing.copyWith(
          categoryId: categoryId,
          name: name,
          unit: unit,
          defaultPrice: price,
          active: active,
        ),
        actor,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.t('product_updated'))),
        );
      }
    }
  }

  String _unitLabel(ProductUnit u, AppLocalizations t) {
    switch (u) {
      case ProductUnit.litre:
        return t.t('unit_litre');
      case ProductUnit.ml:
        return t.t('unit_ml');
      case ProductUnit.kg:
        return t.t('unit_kg');
      case ProductUnit.gram:
        return t.t('unit_gram');
      case ProductUnit.piece:
        return t.t('unit_piece');
    }
  }
}

// ───────────────────────────── Categories tab ─────────────────────────────

class _CategoriesTab extends ConsumerWidget {
  const _CategoriesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Stack(
      children: [
        categoriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (rows) {
            if (rows.isEmpty) {
              return Center(child: Text(t.t('no_categories')));
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (_, i) {
                final c = rows[i];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.category),
                    ),
                    title: Text(c.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.edit),
                    onTap: () => _editCategory(context, ref, c),
                  ),
                );
              },
            );
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () => _editCategory(context, ref, null),
            icon: const Icon(Icons.add),
            label: Text(t.t('add_category')),
          ),
        ),
      ],
    );
  }

  Future<void> _editCategory(
      BuildContext context, WidgetRef ref, ProductCategory? existing) async {
    final t = AppLocalizations.of(context);
    final nameCtrl = TextEditingController(text: existing?.name ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            existing == null ? t.t('add_category') : t.t('edit_category')),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(labelText: t.t('product_name')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t.t('save'))),
        ],
      ),
    );
    if (ok != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    final actor = ref.read(sessionControllerProvider).user!;
    final repo = ref.read(categoryRepositoryProvider);
    if (existing == null) {
      await repo.create(name: name, actor: actor);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.t('category_added'))),
        );
      }
    } else {
      await repo.update(existing.copyWith(name: name), actor);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.t('category_updated'))),
        );
      }
    }
  }
}
