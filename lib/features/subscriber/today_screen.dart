import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/daily_delivery.dart';
import '../../data/models/flat.dart';
import '../../providers/data_providers.dart';
import '../../providers/repository_providers.dart';
import '../auth/session_controller.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final flat = ref.watch(myFlatProvider);
    if (flat == null) return const SizedBox.shrink();
    final history = ref.watch(deliveriesForFlatProvider(flat.id));
    final today = AppDates.dateKey(AppDates.today());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${t.t('today_label')} · Flat ${flat.flatNumber}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                history.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('$e'),
                  data: (rows) {
                    final todayRow =
                        rows.where((r) => r.dateKey == today).toList();
                    if (todayRow.isEmpty) {
                      return _SchedulePreview(
                          quantity: flat.defaultQuantity,
                          status: DeliveryStatus.pending);
                    }
                    return _SchedulePreview(
                        quantity: todayRow.first.actualQuantity > 0
                            ? todayRow.first.actualQuantity
                            : todayRow.first.plannedQuantity,
                        status: todayRow.first.status);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _ActionGrid(flat: flat),
      ],
    );
  }
}

class _SchedulePreview extends StatelessWidget {
  const _SchedulePreview({required this.quantity, required this.status});

  final double quantity;
  final DeliveryStatus status;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final color = switch (status) {
      DeliveryStatus.delivered => Colors.green,
      DeliveryStatus.skipped => Colors.orange,
      DeliveryStatus.paused => Colors.purple,
      DeliveryStatus.pending => Colors.blueGrey,
    };
    final label = switch (status) {
      DeliveryStatus.delivered => t.t('delivered'),
      DeliveryStatus.skipped => t.t('skipped'),
      DeliveryStatus.paused => t.t('paused'),
      DeliveryStatus.pending => t.t('pending'),
    };
    return Row(
      children: [
        Icon(Icons.local_drink, size: 36, color: color),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${quantity}L',
                style: Theme.of(context).textTheme.headlineMedium),
            Text(label, style: TextStyle(color: color)),
          ],
        ),
      ],
    );
  }
}

class _ActionGrid extends ConsumerWidget {
  const _ActionGrid({required this.flat});

  final Flat flat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final today = AppDates.today();
    final tomorrow = today.add(const Duration(days: 1));
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _BigButton(
          icon: Icons.pause_circle,
          label: t.t('pause_today'),
          onTap: () => _submitPause(context, ref, today, today),
        ),
        _BigButton(
          icon: Icons.snooze,
          label: t.t('pause_tomorrow'),
          onTap: () => _submitPause(context, ref, tomorrow, tomorrow),
        ),
        _BigButton(
          icon: Icons.date_range,
          label: t.t('pause_range'),
          onTap: () => _submitPauseRange(context, ref),
        ),
        _BigButton(
          icon: Icons.exposure,
          label: t.t('change_quantity'),
          onTap: () => _submitQuantity(context, ref),
        ),
      ],
    );
  }

  Future<void> _submitPause(BuildContext context, WidgetRef ref,
      DateTime from, DateTime to) async {
    final t = AppLocalizations.of(context);
    final actor = ref.read(sessionControllerProvider).user!;
    await ref.read(changeRequestRepositoryProvider).createPause(
          flatId: flat.id,
          actor: actor,
          fromDate: from,
          toDate: to,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.t('request_submitted'))),
      );
    }
  }

  Future<void> _submitPauseRange(BuildContext context, WidgetRef ref) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    if (!context.mounted) return;
    await _submitPause(context, ref, picked.start, picked.end);
  }

  Future<void> _submitQuantity(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context);
    final qty = TextEditingController(text: flat.defaultQuantity.toString());
    DateTimeRange? range;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(t.t('change_quantity')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qty,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    InputDecoration(labelText: t.t('change_qty_dialog')),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final r = await showDateRangePicker(
                    context: ctx,
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 1)),
                    lastDate:
                        DateTime.now().add(const Duration(days: 365)),
                  );
                  if (r != null) setState(() => range = r);
                },
                icon: const Icon(Icons.date_range),
                label: Text(range == null
                    ? t.t('select_dates')
                    : '${range!.start.toIso8601String().substring(0, 10)} → ${range!.end.toIso8601String().substring(0, 10)}'),
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
      ),
    );
    if (ok != true) return;
    final newQty = double.tryParse(qty.text);
    if (newQty == null || range == null) return;
    final actor = ref.read(sessionControllerProvider).user!;
    await ref.read(changeRequestRepositoryProvider).createQuantityChange(
          flatId: flat.id,
          actor: actor,
          fromDate: range!.start,
          toDate: range!.end,
          newQuantity: newQty,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.t('request_submitted'))),
      );
    }
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: scheme.onPrimaryContainer),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
