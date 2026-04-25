import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/whatsapp.dart';
import '../../../data/models/daily_delivery.dart';
import '../../../data/models/flat.dart';
import '../../../data/models/society.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../auth/session_controller.dart';

class TodaysRouteScreen extends ConsumerWidget {
  const TodaysRouteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final flatsAsync = ref.watch(flatsForCurrentMilkmanProvider);
    final societiesAsync = ref.watch(societiesForCurrentMilkmanProvider);
    final routeAsync = ref.watch(todaysRouteProvider);

    if (flatsAsync.isLoading ||
        societiesAsync.isLoading ||
        routeAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final flats = flatsAsync.value ?? [];
    final societies = societiesAsync.value ?? [];
    final rows = routeAsync.value ?? [];
    if (flats.isEmpty) {
      return Center(child: Text(t.t('no_flats')));
    }

    final rowsByFlat = {for (final r in rows) r.flatId: r};
    final grouped = groupBy(flats, (f) => f.societyId);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final society in societies)
          _SocietyBlock(
            society: society,
            flats: grouped[society.id] ?? const [],
            rowsByFlat: rowsByFlat,
          ),
      ],
    );
  }
}

class _SocietyBlock extends ConsumerWidget {
  const _SocietyBlock({
    required this.society,
    required this.flats,
    required this.rowsByFlat,
  });

  final Society society;
  final List<Flat> flats;
  final Map<String, DailyDelivery> rowsByFlat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (flats.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              society.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(height: 16),
            for (final f in flats)
              _DeliveryRow(
                flat: f,
                row: rowsByFlat[f.id],
              ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryRow extends ConsumerWidget {
  const _DeliveryRow({required this.flat, required this.row});

  final Flat flat;
  final DailyDelivery? row;

  Color _statusColor(BuildContext context, DeliveryStatus s) {
    final scheme = Theme.of(context).colorScheme;
    return switch (s) {
      DeliveryStatus.delivered => Colors.green,
      DeliveryStatus.skipped => Colors.orange,
      DeliveryStatus.paused => scheme.tertiary,
      DeliveryStatus.pending => scheme.outline,
    };
  }

  IconData _statusIcon(DeliveryStatus s) => switch (s) {
        DeliveryStatus.delivered => Icons.check_circle,
        DeliveryStatus.skipped => Icons.do_not_disturb_on,
        DeliveryStatus.paused => Icons.pause_circle,
        DeliveryStatus.pending => Icons.radio_button_unchecked,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final status = row?.status ?? DeliveryStatus.pending;
    final qty = row?.actualQuantity ?? 0;
    final planned = row?.plannedQuantity ?? flat.defaultQuantity;
    final actor = ref.read(sessionControllerProvider).user!;
    final repo = ref.read(deliveryRepositoryProvider);

    return InkWell(
      onLongPress: () => _changeQty(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(_statusIcon(status), color: _statusColor(context, status), size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Flat ${flat.flatNumber} · ${flat.ownerName}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    status == DeliveryStatus.delivered
                        ? '${t.t('delivered')} · ${qty}L'
                        : '${t.t('qty_label')}: ${planned}L',
                    style: TextStyle(color: _statusColor(context, status)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Big tap target: one-tap "Delivered" (default qty).
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(110, 48),
                backgroundColor: status == DeliveryStatus.delivered
                    ? Colors.green.withOpacity(0.2)
                    : null,
              ),
              onPressed: row == null
                  ? null
                  : () => repo.markDelivered(row!, actor),
              icon: const Icon(Icons.check),
              label: Text(t.t('mark_delivered')),
            ),
            const SizedBox(width: 6),
            IconButton.filledTonal(
              tooltip: t.t('mark_skipped'),
              onPressed: row == null ? null : () => repo.markSkipped(row!, actor),
              icon: const Icon(Icons.cancel_outlined),
            ),
            const SizedBox(width: 4),
            if (!flat.hasApp)
              IconButton(
                tooltip: t.t('whatsapp_notify'),
                color: Colors.green.shade700,
                icon: const Icon(Icons.send_outlined),
                onPressed: () => WhatsAppLink.send(
                  flat.ownerPhone,
                  'Hi ${flat.ownerName}, today\'s milk: ${qty}L delivered.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeQty(BuildContext context, WidgetRef ref) async {
    if (row == null) return;
    final t = AppLocalizations.of(context);
    final qtyC = TextEditingController(text: row!.plannedQuantity.toString());
    final reasonC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.t('change_quantity')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyC,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: t.t('change_qty_dialog')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonC,
              decoration: InputDecoration(labelText: t.t('reason_optional')),
            ),
          ],
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
    final qty = double.tryParse(qtyC.text);
    if (qty == null) return;
    final actor = ref.read(sessionControllerProvider).user!;
    final repo = ref.read(deliveryRepositoryProvider);
    final updated = await repo.setQuantity(row!, actor, qty,
        reason: reasonC.text.trim().isEmpty ? null : reasonC.text.trim());
    await repo.markDelivered(updated, actor,
        reason: reasonC.text.trim().isEmpty ? null : reasonC.text.trim());
  }
}
