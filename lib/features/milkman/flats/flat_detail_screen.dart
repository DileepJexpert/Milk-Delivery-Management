import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/audit_log.dart';
import '../../../data/models/daily_delivery.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/repository_providers.dart';

class FlatDetailScreen extends ConsumerWidget {
  const FlatDetailScreen({super.key, required this.flatId});

  final String flatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final flat = ref.watch(flatRepositoryProvider).byId(flatId);
    final audit = ref.watch(auditForFlatProvider(flatId));
    final history = ref.watch(deliveriesForFlatProvider(flatId));

    if (flat == null) {
      return const Scaffold(body: Center(child: Text('Flat not found')));
    }

    return Scaffold(
      appBar: AppBar(title: Text('Flat ${flat.flatNumber} — ${flat.ownerName}')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${t.t('owner_phone')}: ${flat.ownerPhone}'),
                  Text(
                      '${t.t('default_quantity')}: ${flat.defaultQuantity}L'),
                  Text(
                      '${t.t('price_per_litre')}: ₹${flat.pricePerLitre.toStringAsFixed(2)}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(t.t('subscriber_history'),
              style: Theme.of(context).textTheme.titleMedium),
          history.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('$e'),
            data: (rows) => Column(
              children: [
                if (rows.isEmpty) Text(t.t('no_history')),
                for (final r in rows.take(20))
                  ListTile(
                    dense: true,
                    leading: Icon(
                      r.status == DeliveryStatus.delivered
                          ? Icons.check_circle
                          : Icons.cancel,
                      color: r.status == DeliveryStatus.delivered
                          ? Colors.green
                          : Colors.orange,
                    ),
                    title: Text(r.dateKey),
                    trailing: Text('${r.actualQuantity}L'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(t.t('audit_log'),
              style: Theme.of(context).textTheme.titleMedium),
          audit.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('$e'),
            data: (rows) => Column(
              children: [
                for (final a in rows) _AuditTile(a: a),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.a});

  final AuditLog a;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        title: Text(a.changeType.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${t.t('old')}: ${a.oldValue}  →  ${t.t('new')}: ${a.newValue}'),
            Text('${t.t('by')} ${a.changedByName} (${a.changedByPhone})'),
            Text(
              '${AppDates.prettyDate(a.timestamp, locale: Localizations.localeOf(context).languageCode)}'
              '  ${TimeOfDay.fromDateTime(a.timestamp).format(context)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (a.reason != null && a.reason!.isNotEmpty)
              Text('"${a.reason}"',
                  style: const TextStyle(fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }
}
