import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_localizations.dart';
import '../../data/models/daily_delivery.dart';
import '../../providers/data_providers.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final flat = ref.watch(myFlatProvider);
    if (flat == null) return const SizedBox.shrink();
    final history = ref.watch(deliveriesForFlatProvider(flat.id));
    return history.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (rows) {
        if (rows.isEmpty) return Center(child: Text(t.t('no_history')));
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final r = rows[i];
            return ListTile(
              leading: Icon(
                r.status == DeliveryStatus.delivered
                    ? Icons.check_circle
                    : Icons.cancel,
                color: r.status == DeliveryStatus.delivered
                    ? Colors.green
                    : Colors.orange,
              ),
              title: Text(r.dateKey),
              subtitle: Text(r.status.name),
              trailing: Text('${r.actualQuantity}L',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            );
          },
        );
      },
    );
  }
}
