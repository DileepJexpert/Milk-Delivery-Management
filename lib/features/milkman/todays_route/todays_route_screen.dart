import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/whatsapp.dart';
import '../../../data/models/daily_delivery.dart';
import '../../../data/models/flat.dart';
import '../../../data/models/milkman_absence.dart';
import '../../../data/models/product.dart';
import '../../../data/models/society.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../auth/session_controller.dart';
import '../absences/broadcast_absence_screen.dart';
import '../absences/manage_absences_screen.dart';

class TodaysRouteScreen extends ConsumerWidget {
  const TodaysRouteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final flatsAsync = ref.watch(flatsForCurrentMilkmanProvider);
    final societiesAsync = ref.watch(societiesForCurrentMilkmanProvider);
    final routeAsync = ref.watch(todaysRouteProvider);
    final productsAsync = ref.watch(productsProvider);

    if (flatsAsync.isLoading ||
        societiesAsync.isLoading ||
        routeAsync.isLoading ||
        productsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final flats = flatsAsync.value ?? [];
    final societies = societiesAsync.value ?? [];
    final rows = routeAsync.value ?? [];
    final products = productsAsync.value ?? [];
    if (flats.isEmpty) {
      return Center(child: Text(t.t('no_flats')));
    }

    final activeFlats =
        flats.where((f) => f.status != FlatStatus.stopped).toList();
    final productsById = {for (final p in products) p.id: p};

    // Group all delivery rows by flat id, then sort each list by product name.
    final rowsByFlat = <String, List<DailyDelivery>>{};
    for (final r in rows) {
      rowsByFlat.putIfAbsent(r.flatId, () => []).add(r);
    }
    for (final list in rowsByFlat.values) {
      list.sort((a, b) {
        final an = productsById[a.productId]?.name ?? '';
        final bn = productsById[b.productId]?.name ?? '';
        return an.compareTo(bn);
      });
    }

    final grouped = groupBy(activeFlats, (f) => f.societyId);
    final standaloneFlats = activeFlats.where((f) => f.isStandalone).toList();
    final isOffToday = ref.watch(isMilkmanAbsentTodayProvider);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (isOffToday) const _OffTodayBanner() else const _OffTodayCta(),
        const SizedBox(height: 12),
        for (final society in societies)
          _SocietyBlock(
            society: society,
            flats: grouped[society.id] ?? const [],
            rowsByFlat: rowsByFlat,
            productsById: productsById,
          ),
        if (standaloneFlats.isNotEmpty)
          _SocietyBlock(
            society: null,
            flats: standaloneFlats,
            rowsByFlat: rowsByFlat,
            productsById: productsById,
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
    required this.productsById,
  });

  final Society? society;
  final List<Flat> flats;
  final Map<String, List<DailyDelivery>> rowsByFlat;
  final Map<String, Product> productsById;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (flats.isEmpty) return const SizedBox.shrink();
    final t = AppLocalizations.of(context);
    final label = society?.name ?? t.t('standalone_customers');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  society == null
                      ? Icons.home_outlined
                      : Icons.apartment_outlined,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const Divider(height: 16),
            for (final f in flats)
              _FlatBlock(
                flat: f,
                rows: rowsByFlat[f.id] ?? const [],
                productsById: productsById,
              ),
          ],
        ),
      ),
    );
  }
}

class _FlatBlock extends ConsumerWidget {
  const _FlatBlock({
    required this.flat,
    required this.rows,
    required this.productsById,
  });

  final Flat flat;
  final List<DailyDelivery> rows;
  final Map<String, Product> productsById;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isPrepaid = flat.billingMode == BillingMode.prepaid;
    final balanceLow = isPrepaid && flat.walletBalance < 100;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Flat header
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: scheme.primaryContainer,
                child: Text(
                  flat.flatNumber.substring(0, 1),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: scheme.onPrimaryContainer,
                      fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      flat.isStandalone
                          ? '${flat.flatNumber} · ${flat.ownerName}'
                          : 'Flat ${flat.flatNumber} · ${flat.ownerName}',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    if (flat.addressLine != null &&
                        flat.addressLine!.isNotEmpty)
                      Text(
                        flat.addressLine!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                  ],
                ),
              ),
              if (isPrepaid)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: balanceLow
                        ? Colors.red.withOpacity(0.15)
                        : Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '₹${flat.walletBalance.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: balanceLow ? Colors.red : Colors.green.shade800,
                    ),
                  ),
                ),
            ],
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(36, 4, 0, 4),
              child: Text(
                t.t('no_subscriptions_short'),
                style: TextStyle(color: scheme.outline, fontSize: 12),
              ),
            )
          else
            for (final row in rows)
              _ProductRow(
                flat: flat,
                row: row,
                product: productsById[row.productId],
              ),
          const Divider(height: 16, indent: 36),
        ],
      ),
    );
  }
}

class _ProductRow extends ConsumerWidget {
  const _ProductRow({
    required this.flat,
    required this.row,
    required this.product,
  });

  final Flat flat;
  final DailyDelivery row;
  final Product? product;

  Color _statusColor(BuildContext context, DeliveryStatus s) {
    final scheme = Theme.of(context).colorScheme;
    return switch (s) {
      DeliveryStatus.delivered => Colors.green,
      DeliveryStatus.skipped => Colors.orange,
      DeliveryStatus.paused => scheme.tertiary,
      DeliveryStatus.milkmanAbsent => scheme.error,
      DeliveryStatus.pending => scheme.outline,
    };
  }

  IconData _statusIcon(DeliveryStatus s) => switch (s) {
        DeliveryStatus.delivered => Icons.check_circle,
        DeliveryStatus.skipped => Icons.do_not_disturb_on,
        DeliveryStatus.paused => Icons.pause_circle,
        DeliveryStatus.milkmanAbsent => Icons.event_busy,
        DeliveryStatus.pending => Icons.radio_button_unchecked,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final status = row.status;
    final qty = row.actualQuantity;
    final planned = row.plannedQuantity;
    final unit = product?.unit.short ?? '';
    final name = product?.name ?? '—';
    final repo = ref.read(deliveryRepositoryProvider);

    return InkWell(
      onLongPress: () => _changeQty(context, ref),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 6, 0, 6),
        child: Row(
          children: [
            Icon(_statusIcon(status),
                color: _statusColor(context, status), size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    status == DeliveryStatus.delivered
                        ? '${t.t('delivered')} · $qty $unit'
                        : '${t.t('qty_label')}: $planned $unit  ·  ₹${row.unitPrice.toStringAsFixed(0)}/$unit',
                    style: TextStyle(
                        color: _statusColor(context, status), fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(90, 38),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                backgroundColor: status == DeliveryStatus.delivered
                    ? Colors.green.withOpacity(0.2)
                    : null,
              ),
              onPressed: () {
                final actor = ref.read(sessionControllerProvider).user;
                if (actor == null) return;
                repo.markDelivered(row, actor);
              },
              icon: const Icon(Icons.check, size: 16),
              label: Text(t.t('mark_delivered'),
                  style: const TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 4),
            IconButton.filledTonal(
              tooltip: t.t('mark_skipped'),
              iconSize: 20,
              onPressed: () {
                final actor = ref.read(sessionControllerProvider).user;
                if (actor == null) return;
                repo.markSkipped(row, actor);
              },
              icon: const Icon(Icons.cancel_outlined),
            ),
            if (!flat.hasApp)
              IconButton(
                tooltip: t.t('whatsapp_notify'),
                iconSize: 20,
                color: Colors.green.shade700,
                icon: const Icon(Icons.send_outlined),
                onPressed: () => WhatsAppLink.send(
                  flat.ownerPhone,
                  'Hi ${flat.ownerName}, today: $qty $unit $name delivered.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeQty(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context);
    final qtyC = TextEditingController(text: row.plannedQuantity.toString());
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
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  InputDecoration(labelText: t.t('change_qty_dialog')),
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
    final updated = await repo.setQuantity(row, actor, qty,
        reason: reasonC.text.trim().isEmpty ? null : reasonC.text.trim());
    await repo.markDelivered(updated, actor,
        reason: reasonC.text.trim().isEmpty ? null : reasonC.text.trim());
  }
}

class _OffTodayCta extends ConsumerWidget {
  const _OffTodayCta();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.event_busy, size: 28, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.t('im_off_today'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(t.t('absent_today_banner_explainer'),
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: () => _markOffToday(context, ref),
              child: Text(t.t('im_off_today')),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: t.t('manage_absences'),
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ManageAbsencesScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markOffToday(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context);
    final actor = ref.read(sessionControllerProvider).user;
    if (actor == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.t('im_off_today')),
        content: Text(t.t('absent_today_banner_explainer')),
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
    if (confirm != true) return;
    final created = await ref
        .read(absenceRepositoryProvider)
        .createForToday(milkman: actor);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BroadcastAbsenceScreen(absence: created),
      ),
    );
  }
}

class _OffTodayBanner extends ConsumerWidget {
  const _OffTodayBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.event_busy, size: 32, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.t('milkman_off_today'),
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: scheme.onErrorContainer)),
                  Text(t.t('absent_today_banner_explainer'),
                      style: TextStyle(color: scheme.onErrorContainer)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => _undoOffToday(context, ref),
              child: Text(t.t('undo_off_today')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _undoOffToday(BuildContext context, WidgetRef ref) async {
    final actor = ref.read(sessionControllerProvider).user;
    if (actor == null) return;
    final absences =
        await ref.read(absencesForCurrentMilkmanProvider.future);
    final today = AppDates.today();
    final todayKey = AppDates.dateKey(today);
    MilkmanAbsence? hit;
    for (final a in absences) {
      if (a.isRecurring) {
        if (a.recurringDayOfWeek == today.weekday) {
          hit = a;
          break;
        }
      } else if (todayKey.compareTo(a.fromDateKey) >= 0 &&
          todayKey.compareTo(a.toDateKey) <= 0) {
        hit = a;
        break;
      }
    }
    if (hit != null) {
      await ref.read(absenceRepositoryProvider).delete(hit.id, actor);
    }
  }
}
