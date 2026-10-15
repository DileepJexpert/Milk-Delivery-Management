import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_utils.dart';
import '../../../data/models/flat.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/repository_providers.dart';

class FarmPantryItem {
  final String id;
  final String name;
  final String unit;
  final double price;
  final String tag;
  final IconData icon;

  const FarmPantryItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.price,
    required this.tag,
    required this.icon,
  });
}

const milterraPantryItems = [
  FarmPantryItem(
    id: 'a2_ghee',
    name: 'A2 Gir Cow Bilona Ghee',
    unit: '500 ml',
    price: 850,
    tag: 'Bestseller',
    icon: Icons.wb_sunny_outlined,
  ),
  FarmPantryItem(
    id: 'white_butter',
    name: 'Vedic White Butter (Makhan)',
    unit: '250 g',
    price: 220,
    tag: 'Fresh Churned',
    icon: Icons.breakfast_dining_outlined,
  ),
  FarmPantryItem(
    id: 'raw_honey',
    name: 'Raw Wild Forest Honey',
    unit: '500 g',
    price: 450,
    tag: 'Unfiltered',
    icon: Icons.hive_outlined,
  ),
  FarmPantryItem(
    id: 'clay_pot_dahi',
    name: 'Clay-Pot Set Vedic Dahi',
    unit: '400 g',
    price: 75,
    tag: 'Probiotic',
    icon: Icons.eco_outlined,
  ),
];

class FarmPantryCrossSell extends ConsumerWidget {
  const FarmPantryCrossSell({super.key, required this.flat});

  final Flat flat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tomorrow = AppDates.today().add(const Duration(days: 1));
    final tomorrowKey = AppDates.dateKey(tomorrow);
    final historyAsync = ref.watch(deliveriesForFlatProvider(flat.id));
    final deliveryRepo = ref.read(deliveryRepositoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.storefront_outlined, color: Colors.amber),
            const SizedBox(width: 8),
            Text(
              'Milterra Farm Pantry',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Add organic farm staples directly to tomorrow\'s morning milk drop:',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
        const SizedBox(height: 12),
        historyAsync.maybeWhen(
          data: (rows) {
            final tomorrowRow = rows.where((r) => r.dateKey == tomorrowKey).firstOrNull;
            final currentNotes = tomorrowRow?.notes ?? '';

            return Column(
              children: milterraPantryItems.map((item) {
                final isAdded = currentNotes.contains(item.name);

                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(item.icon, color: Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      item.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item.tag,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.amber.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${item.unit} · ₹${item.price.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isAdded)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green,
                              side: const BorderSide(color: Colors.green),
                            ),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Added'),
                            onPressed: () async {
                              final row = deliveryRepo.ensureForToday(flat, when: tomorrow);
                              final updated = currentNotes.replaceAll('+ 1x ${item.name}', '').trim();
                              await deliveryRepo.updateNotes(row, updated);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Removed ${item.name} from tomorrow\'s drop')),
                                );
                              }
                            },
                          )
                        else
                          FilledButton.tonal(
                            child: const Text('+ Add'),
                            onPressed: () async {
                              final row = deliveryRepo.ensureForToday(flat, when: tomorrow);
                              final updated = currentNotes.isEmpty
                                  ? '+ 1x ${item.name}'
                                  : '$currentNotes, + 1x ${item.name}';
                              await deliveryRepo.updateNotes(row, updated);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('✅ Added ${item.name} to tomorrow\'s delivery drop!'),
                                    backgroundColor: Colors.green.shade800,
                                  ),
                                );
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
