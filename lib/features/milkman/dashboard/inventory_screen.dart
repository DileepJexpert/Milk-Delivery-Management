import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/product.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/repository_providers.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  /// Inventory is most useful for tomorrow — what to buy tonight.
  DateTime _date = AppDates.today().add(const Duration(days: 1));

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final products = ref.watch(productsProvider).valueOrNull ?? const [];
    final productsById = {for (final p in products) p.id: p};
    final flatsAsync = ref.watch(flatsForCurrentMilkmanProvider);
    final repo = ref.watch(deliveryRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.t('inventory'))),
      body: flatsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (flats) {
          // Trigger row creation for the chosen date so totals reflect reality
          // (no-op if already there). Fire-and-forget.
          repo.ensureRouteForToday(flats);
          final totals = repo.inventoryFor(_date);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(() {
                      _date = _date.subtract(const Duration(days: 1));
                    }),
                  ),
                  Expanded(
                    child: Text(
                      AppDates.dateKey(_date),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setState(() {
                      _date = _date.add(const Duration(days: 1));
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (totals.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text(
                    t.t('no_deliveries_today'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.outline),
                  ),
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        for (final entry in (totals.entries.toList()
                              ..sort((a, b) => b.value.compareTo(a.value))))
                          _InventoryRow(
                            product: productsById[entry.key],
                            quantity: entry.value,
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _InventoryRow extends StatelessWidget {
  const _InventoryRow({required this.product, required this.quantity});
  final Product? product;
  final double quantity;

  @override
  Widget build(BuildContext context) {
    final name = product?.name ?? '—';
    final unit = product?.unit.short ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor:
                Theme.of(context).colorScheme.primaryContainer,
            child: const Icon(Icons.inventory_2_outlined, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          Text(
            '${quantity.toStringAsFixed(2)} $unit',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
