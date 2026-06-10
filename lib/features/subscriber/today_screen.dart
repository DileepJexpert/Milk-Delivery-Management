import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/indian_holidays.dart';
import '../../core/utils/upi_link.dart';
import '../../data/models/daily_delivery.dart';
import '../../data/models/flat.dart';
import '../../data/models/product.dart';
import '../../data/models/subscription.dart';
import '../../features/milkman/settings/milkman_settings.dart';
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
    final mySubs =
        ref.watch(mySubscriptionsProvider).valueOrNull ?? const <Subscription>[];
    final activeSubs =
        mySubs.where((s) => s.status == SubscriptionStatus.active).toList();
    final products = ref.watch(productsProvider).valueOrNull ?? const <Product>[];
    final productsById = {for (final p in products) p.id: p};
    final history = ref.watch(deliveriesForFlatProvider(flat.id));
    final today = AppDates.dateKey(AppDates.today());
    final milkmanOff = ref.watch(isMyMilkmanAbsentTodayProvider);

    final onVacation = flat.isOnVacation(today);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (milkmanOff) const _MilkmanOffBanner(),
        if (milkmanOff) const SizedBox(height: 12),

        _VacationCard(flat: flat, onVacation: onVacation),
        const SizedBox(height: 8),
        _FestivalToggle(flat: flat),
        const SizedBox(height: 12),

        if (flat.billingMode == BillingMode.prepaid)
          _WalletStrip(flat: flat),
        if (flat.billingMode == BillingMode.prepaid)
          const SizedBox(height: 12),

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
                const SizedBox(height: 4),
                Text(t.t('todays_items'),
                    style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 12),
                history.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('$e'),
                  data: (rows) {
                    if (activeSubs.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(t.t('no_subscriptions')),
                      );
                    }
                    return Column(
                      children: [
                        for (final s in activeSubs)
                          _SubscriptionLine(
                            subscription: s,
                            product: productsById[s.productId],
                            todayRow: rows.firstWhere(
                              (r) =>
                                  r.dateKey == today &&
                                  r.productId == s.productId,
                              orElse: () => DailyDelivery(
                                id: '',
                                flatId: flat.id,
                                productId: s.productId,
                                dateKey: today,
                                plannedQuantity: s.quantity,
                                actualQuantity: 0,
                                unitPrice: s.unitPrice,
                                status: milkmanOff
                                    ? DeliveryStatus.milkmanAbsent
                                    : DeliveryStatus.pending,
                              ),
                            ),
                            milkmanOff: milkmanOff,
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!milkmanOff) _ActionGrid(flat: flat),
      ],
    );
  }
}

class _WalletStrip extends ConsumerWidget {
  const _WalletStrip({required this.flat});
  final Flat flat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final low = flat.walletBalance < 100;
    final scheme = Theme.of(context).colorScheme;
    final settings = ref.watch(milkmanSettingsProvider);
    // Suggest topping up to ₹500 if balance is low.
    final suggestedTopup =
        flat.walletBalance < 100 ? 500.0 - flat.walletBalance : 0.0;

    return Card(
      color: low
          ? scheme.errorContainer
          : Colors.green.withOpacity(0.15),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  low ? Icons.warning : Icons.account_balance_wallet,
                  color: low ? scheme.onErrorContainer : Colors.green.shade800,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.t('wallet_balance'),
                          style: TextStyle(
                            color: low ? scheme.onErrorContainer : null,
                            fontSize: 12,
                          )),
                      Text(
                        '₹${flat.walletBalance.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: low
                              ? scheme.onErrorContainer
                              : Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (low)
                  Text(t.t('low_balance'),
                      style: TextStyle(
                        color: scheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      )),
              ],
            ),
            if (low && settings.hasUpi) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => UpiLink.launch(
                    vpa: settings.upiId!,
                    name: settings.upiPayeeName ?? 'Milkman',
                    amount: suggestedTopup,
                    note: 'Wallet top-up',
                  ),
                  icon: const Icon(Icons.payment),
                  label: Text(
                    '${t.t('topup_via_upi')} · ₹${suggestedTopup.toStringAsFixed(0)}',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SubscriptionLine extends StatelessWidget {
  const _SubscriptionLine({
    required this.subscription,
    required this.product,
    required this.todayRow,
    required this.milkmanOff,
  });

  final Subscription subscription;
  final Product? product;
  final DailyDelivery todayRow;
  final bool milkmanOff;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final status = milkmanOff ? DeliveryStatus.milkmanAbsent : todayRow.status;
    final name = product?.name ?? '—';
    final unit = product?.unit.short ?? '';
    final color = switch (status) {
      DeliveryStatus.delivered => Colors.green,
      DeliveryStatus.skipped => Colors.orange,
      DeliveryStatus.paused => Colors.purple,
      DeliveryStatus.milkmanAbsent => Colors.red,
      DeliveryStatus.pending => Colors.blueGrey,
    };
    final label = switch (status) {
      DeliveryStatus.delivered => t.t('delivered'),
      DeliveryStatus.skipped => t.t('skipped'),
      DeliveryStatus.paused => t.t('paused'),
      DeliveryStatus.milkmanAbsent => t.t('milkman_absent'),
      DeliveryStatus.pending => t.t('pending'),
    };
    final qty = status == DeliveryStatus.delivered
        ? todayRow.actualQuantity
        : subscription.quantity;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.local_drink, color: color, size: 32),
      title: Text(name,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        '$qty $unit · ₹${subscription.unitPrice.toStringAsFixed(0)}/$unit',
      ),
      trailing: Text(label, style: TextStyle(color: color)),
    );
  }
}

class _MilkmanOffBanner extends StatelessWidget {
  const _MilkmanOffBanner();

  @override
  Widget build(BuildContext context) {
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
                  Text(t.t('no_delivery_today'),
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: scheme.onErrorContainer)),
                  Text(t.t('no_delivery_explainer'),
                      style: TextStyle(color: scheme.onErrorContainer)),
                ],
              ),
            ),
          ],
        ),
      ),
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
        _BigButton(
          icon: Icons.add_shopping_cart,
          label: t.t('add_one_time'),
          onTap: () => _submitOneTime(context, ref),
        ),
      ],
    );
  }

  Future<void> _submitOneTime(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context);
    final subs = ref
            .read(mySubscriptionsProvider)
            .valueOrNull
            ?.where((s) => s.status.name == 'active')
            .toList() ??
        const [];
    if (subs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.t('no_subscriptions'))),
      );
      return;
    }
    final products =
        ref.read(productsProvider).valueOrNull ?? const <Product>[];
    final productsById = {for (final p in products) p.id: p};
    final qty = TextEditingController(text: subs.first.quantity.toString());
    String chosen = subs.first.productId;
    DateTime when = AppDates.today();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: Text(t.t('add_one_time')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: chosen,
                  decoration: InputDecoration(labelText: t.t('products')),
                  items: subs
                      .map((s) => DropdownMenuItem(
                            value: s.productId,
                            child: Text(productsById[s.productId]?.name ?? '—'),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setInner(() => chosen = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qty,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      InputDecoration(labelText: t.t('change_qty_dialog')),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(AppDates.dateKey(when)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: when,
                      firstDate: AppDates.today(),
                      lastDate:
                          AppDates.today().add(const Duration(days: 30)),
                    );
                    if (picked != null) setInner(() => when = picked);
                  },
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
    final q = double.tryParse(qty.text);
    if (q == null || q <= 0) return;
    final actor = ref.read(sessionControllerProvider).user;
    if (actor == null) return;
    final matching = subs.firstWhere((s) => s.productId == chosen);
    await ref.read(deliveryRepositoryProvider).createOneTime(
          flat: flat,
          productId: chosen,
          quantity: q,
          unitPrice: matching.unitPrice,
          when: when,
          actor: actor,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.t('one_time_added'))),
      );
    }
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
                    lastDate: DateTime.now().add(const Duration(days: 365)),
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

class _VacationCard extends ConsumerWidget {
  const _VacationCard({required this.flat, required this.onVacation});

  final Flat flat;
  final bool onVacation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (onVacation) {
      return Card(
        color: Colors.purple.withOpacity(0.12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.beach_access, size: 28, color: Colors.purple),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.t('on_vacation'),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(
                      '${flat.vacationFromKey} -> ${flat.vacationToKey}',
                      style: TextStyle(
                          color: scheme.outline, fontSize: 12),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () async {
                  final actor = ref.read(sessionControllerProvider).user;
                  if (actor == null) return;
                  await ref
                      .read(flatRepositoryProvider)
                      .endVacation(flat, actor);
                },
                child: Text(t.t('cancel_vacation')),
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      child: ListTile(
        leading: const Icon(Icons.beach_access_outlined),
        title: Text(t.t('vacation_mode')),
        subtitle: Text(t.t('vacation_explainer')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _startVacation(context, ref),
      ),
    );
  }

  Future<void> _startVacation(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
      helpText: t.t('vacation_mode'),
    );
    if (picked == null) return;
    final actor = ref.read(sessionControllerProvider).user;
    if (actor == null) return;
    await ref
        .read(flatRepositoryProvider)
        .startVacation(flat, actor, picked.start, picked.end);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.t('vacation_started'))),
      );
    }
  }
}

class _FestivalToggle extends ConsumerWidget {
  const _FestivalToggle({required this.flat});
  final Flat flat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final todayKey = AppDates.dateKey(AppDates.today());
    final festivalName = IndianHolidays.nameFor(todayKey);
    return Card(
      child: SwitchListTile(
        secondary: Icon(
          Icons.celebration_outlined,
          color: festivalName != null ? Colors.amber.shade700 : null,
        ),
        title: Text(t.t('pause_on_festivals')),
        subtitle: festivalName != null
            ? Text('${t.t('festival_today')}: $festivalName',
                style: TextStyle(color: Colors.amber.shade800))
            : Text(t.t('pause_on_festivals_explainer')),
        value: flat.pauseOnFestivals,
        onChanged: (v) async {
          final actor = ref.read(sessionControllerProvider).user;
          if (actor == null) return;
          await ref
              .read(flatRepositoryProvider)
              .setPauseOnFestivals(flat, actor, v);
        },
      ),
    );
  }
}
