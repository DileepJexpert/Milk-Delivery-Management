import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../data/models/product.dart';
import '../../../data/models/subscription.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../auth/session_controller.dart';

class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key, required this.flatId});

  final String flatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final flat = ref.watch(flatRepositoryProvider).byId(flatId);
    final subsAsync = ref.watch(subscriptionsForFlatProvider(flatId));
    final products = ref.watch(productsProvider).valueOrNull ?? const [];
    final productsById = {for (final p in products) p.id: p};

    if (flat == null) {
      return const Scaffold(body: Center(child: Text('Flat not found')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${t.t('subscriptions')} · Flat ${flat.flatNumber}',
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editSubscription(context, ref, null),
        icon: const Icon(Icons.add),
        label: Text(t.t('add_subscription')),
      ),
      body: subsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (subs) {
          if (subs.isEmpty) {
            return Center(child: Text(t.t('no_subscriptions')));
          }
          final active = subs
              .where((s) => s.status == SubscriptionStatus.active)
              .toList();
          final stopped = subs
              .where((s) => s.status == SubscriptionStatus.stopped)
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
            children: [
              for (final s in active)
                _SubTile(
                  s: s,
                  product: productsById[s.productId],
                  onTap: () => _editSubscription(context, ref, s),
                  onStop: () => _stop(context, ref, s),
                  onReactivate: null,
                ),
              if (stopped.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
                  child: Text(
                    t.t('subscription_stopped'),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ),
                for (final s in stopped)
                  _SubTile(
                    s: s,
                    product: productsById[s.productId],
                    onTap: () => _editSubscription(context, ref, s),
                    onStop: null,
                    onReactivate: () => _reactivate(context, ref, s),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _editSubscription(
    BuildContext context,
    WidgetRef ref,
    Subscription? existing,
  ) async {
    final t = AppLocalizations.of(context);
    final activeProducts =
        ref.read(activeProductsProvider).valueOrNull ?? const [];
    if (activeProducts.isEmpty) return;

    String productId =
        existing?.productId ?? activeProducts.first.id;
    final qtyCtrl = TextEditingController(
        text: existing?.quantity.toString() ?? '1.0');
    final priceCtrl = TextEditingController(
      text: existing?.unitPrice.toString() ??
          activeProducts.first.defaultPrice.toString(),
    );
    SchedulePattern pattern = existing?.pattern ?? SchedulePattern.daily;
    final customDays = <int>{
      ...(existing?.weekDays ?? const [1, 2, 3, 4, 5, 6, 7])
    };

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: Text(existing == null
              ? t.t('add_subscription')
              : t.t('manage_subscriptions')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (existing == null)
                  DropdownButtonFormField<String>(
                    value: productId,
                    decoration: InputDecoration(labelText: t.t('products')),
                    items: activeProducts
                        .map((p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(
                                  '${p.name} (₹${p.defaultPrice.toStringAsFixed(2)} / ${p.unit.short})'),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      final p = activeProducts.firstWhere((x) => x.id == v);
                      setInner(() {
                        productId = v;
                        priceCtrl.text = p.defaultPrice.toString();
                      });
                    },
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      activeProducts
                              .where((p) => p.id == existing.productId)
                              .map((p) => p.name)
                              .firstOrNull ??
                          existing.productId,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: t.t('qty')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: t.t('unit_price')),
                ),
                const SizedBox(height: 16),
                Text(t.t('schedule'),
                    style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 6),
                DropdownButtonFormField<SchedulePattern>(
                  value: pattern,
                  items: SchedulePattern.values
                      .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(t.t(p.key)),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setInner(() => pattern = v);
                  },
                ),
                if (pattern == SchedulePattern.custom) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    children: [
                      for (int d = 1; d <= 7; d++)
                        FilterChip(
                          label: Text(_weekdayShort(d, t)),
                          selected: customDays.contains(d),
                          onSelected: (v) => setInner(() {
                            if (v) {
                              customDays.add(d);
                            } else {
                              customDays.remove(d);
                            }
                          }),
                        ),
                    ],
                  ),
                ],
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
    final qty = double.tryParse(qtyCtrl.text);
    final price = double.tryParse(priceCtrl.text);
    if (qty == null || qty <= 0 || price == null) return;
    final actor = ref.read(sessionControllerProvider).user!;
    final repo = ref.read(subscriptionRepositoryProvider);

    final daysList = customDays.toList()..sort();
    if (existing == null) {
      await repo.create(
        flatId: flatId,
        productId: productId,
        quantity: qty,
        unitPrice: price,
        pattern: pattern,
        weekDays:
            daysList.isEmpty ? const [1, 2, 3, 4, 5, 6, 7] : daysList,
        actor: actor,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.t('subscription_added'))));
      }
    } else {
      await repo.update(
        existing,
        actor,
        quantity: qty,
        unitPrice: price,
        pattern: pattern,
        weekDays:
            daysList.isEmpty ? const [1, 2, 3, 4, 5, 6, 7] : daysList,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.t('subscription_updated'))));
      }
    }
  }

  Future<void> _stop(
      BuildContext context, WidgetRef ref, Subscription s) async {
    final actor = ref.read(sessionControllerProvider).user!;
    await ref.read(subscriptionRepositoryProvider).stop(s, actor);
    if (context.mounted) {
      final t = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.t('subscription_removed'))));
    }
  }

  Future<void> _reactivate(
      BuildContext context, WidgetRef ref, Subscription s) async {
    final actor = ref.read(sessionControllerProvider).user!;
    await ref.read(subscriptionRepositoryProvider).reactivate(s, actor);
  }
}

class _SubTile extends StatelessWidget {
  const _SubTile({
    required this.s,
    required this.product,
    required this.onTap,
    required this.onStop,
    required this.onReactivate,
  });

  final Subscription s;
  final Product? product;
  final VoidCallback onTap;
  final VoidCallback? onStop;
  final VoidCallback? onReactivate;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final stopped = s.status == SubscriptionStatus.stopped;
    final unit = product?.unit.short ?? 'L';
    final name = product?.name ?? 'Unknown';

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: stopped
              ? Colors.grey.shade300
              : Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            stopped ? Icons.pause : Icons.local_drink,
            color: stopped
                ? Colors.grey.shade700
                : Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: stopped ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${s.quantity} $unit · ₹${s.unitPrice.toStringAsFixed(2)} / $unit',
            ),
            Text(
              _scheduleLabel(s, t),
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit),
              onPressed: onTap,
            ),
            if (onStop != null)
              IconButton(
                tooltip: t.t('stop_subscription'),
                icon: const Icon(Icons.stop_circle_outlined),
                color: Colors.red,
                onPressed: onStop,
              ),
            if (onReactivate != null)
              IconButton(
                tooltip: t.t('reactivate_subscription'),
                icon: const Icon(Icons.refresh),
                color: Colors.green,
                onPressed: onReactivate,
              ),
          ],
        ),
      ),
    );
  }
}

String _scheduleLabel(Subscription s, AppLocalizations t) {
  if (s.pattern == SchedulePattern.custom) {
    final days = s.weekDays.map((d) => _weekdayShort(d, t)).join(' ');
    return '${t.t(s.pattern.key)} · $days';
  }
  return t.t(s.pattern.key);
}

String _weekdayShort(int day, AppLocalizations t) {
  switch (day) {
    case 1:
      return t.t('mon');
    case 2:
      return t.t('tue');
    case 3:
      return t.t('wed');
    case 4:
      return t.t('thu');
    case 5:
      return t.t('fri');
    case 6:
      return t.t('sat');
    case 7:
      return t.t('sun');
    default:
      return '?';
  }
}
