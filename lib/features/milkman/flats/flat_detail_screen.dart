import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/audit_log.dart';
import '../../../data/models/daily_delivery.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../auth/session_controller.dart';

class FlatDetailScreen extends ConsumerStatefulWidget {
  const FlatDetailScreen({super.key, required this.flatId});

  final String flatId;

  @override
  ConsumerState<FlatDetailScreen> createState() => _FlatDetailScreenState();
}

class _FlatDetailScreenState extends ConsumerState<FlatDetailScreen> {
  Future<void> _showRecordChangeDialog() async {
    final t = AppLocalizations.of(context);
    final flat = ref.read(flatRepositoryProvider).byId(widget.flatId);
    if (flat == null) return;

    final qtyCtrl =
        TextEditingController(text: flat.defaultQuantity.toString());
    final reasonCtrl = TextEditingController();
    DateTime selectedDate = AppDates.today();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: Text(t.t('record_qty_change')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date selector
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(AppDates.dateKey(selectedDate)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 90)),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (picked != null) setInner(() => selectedDate = picked);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      InputDecoration(labelText: t.t('change_qty_dialog')),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonCtrl,
                  decoration:
                      InputDecoration(labelText: t.t('reason_optional')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t.t('save')),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;
    final newQty = double.tryParse(qtyCtrl.text.trim());
    if (newQty == null || newQty <= 0) return;
    final reason =
        reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim();

    final actor = ref.read(sessionControllerProvider).user!;
    final deliveryRepo = ref.read(deliveryRepositoryProvider);
    final row = deliveryRepo.ensureForToday(flat, when: selectedDate);
    await deliveryRepo.setQuantity(row, actor, newQty, reason: reason);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.t('change_recorded'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final flat = ref.watch(flatRepositoryProvider).byId(widget.flatId);
    final audit = ref.watch(auditForFlatProvider(widget.flatId));
    final history = ref.watch(deliveriesForFlatProvider(widget.flatId));

    if (flat == null) {
      return const Scaffold(body: Center(child: Text('Flat not found')));
    }

    return Scaffold(
      appBar:
          AppBar(title: Text('Flat ${flat.flatNumber} — ${flat.ownerName}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRecordChangeDialog,
        icon: const Icon(Icons.edit_note),
        label: Text(t.t('record_qty_change')),
      ),
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
          // Extra bottom padding so FAB doesn't cover last audit entry.
          const SizedBox(height: 80),
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
            Text(
                '${t.t('old')}: ${a.oldValue}  →  ${t.t('new')}: ${a.newValue}'),
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
