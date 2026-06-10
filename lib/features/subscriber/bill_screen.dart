import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/upi_link.dart';
import '../../data/models/flat.dart';
import '../../features/milkman/settings/milkman_settings.dart';
import '../../providers/data_providers.dart';
import '../../providers/repository_providers.dart';

class BillScreen extends ConsumerStatefulWidget {
  const BillScreen({super.key});

  @override
  ConsumerState<BillScreen> createState() => _BillScreenState();
}

class _BillScreenState extends ConsumerState<BillScreen> {
  DateTime _month = AppDates.today();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final flat = ref.watch(myFlatProvider);
    if (flat == null) return const SizedBox.shrink();
    final summary =
        ref.watch(deliveryRepositoryProvider).summary(flat.id, _month);
    final products = ref.watch(productsProvider).valueOrNull ?? const [];
    final productsById = {for (final p in products) p.id: p};
    final locale = Localizations.localeOf(context).languageCode;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() {
                  _month = DateTime(_month.year, _month.month - 1);
                }),
              ),
              Expanded(
                child: Text(
                  AppDates.monthLabel(_month, locale: locale),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() {
                  _month = DateTime(_month.year, _month.month + 1);
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '₹${summary.totalAmount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                      '${t.t('days_delivered_label')}: ${summary.daysDelivered}'),
                  Text(
                      '${t.t('days_subscriber_paused')}: ${summary.daysSubscriberPaused}'),
                  Text(
                      '${t.t('days_milkman_absent')}: ${summary.daysMilkmanAbsent}'),
                  const SizedBox(height: 12),
                  _PayViaUpiButton(
                    amount: summary.totalAmount,
                    note:
                        'Milk bill ${_month.year}-${_month.month.toString().padLeft(2, '0')}',
                  ),
                ],
              ),
            ),
          ),
          if (flat.billingMode == BillingMode.prepaid) ...[
            const SizedBox(height: 12),
            Card(
              color: flat.walletBalance < 0
                  ? Theme.of(context).colorScheme.errorContainer
                  : Colors.green.withOpacity(0.15),
              child: ListTile(
                leading: const Icon(Icons.account_balance_wallet),
                title: Text(t.t('wallet_balance')),
                trailing: Text(
                  '₹${flat.walletBalance.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: flat.walletBalance < 0 ? Colors.red : null,
                  ),
                ),
              ),
            ),
          ],
          // ── Spend tracker (last 6 months) ─────────────────────────
          const SizedBox(height: 16),
          _SpendTracker(flatId: flat.id, anchor: _month),

          if (summary.products.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(t.t('per_product_breakdown'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    for (final line in summary.products)
                      _ProductBillLine(
                        productName:
                            productsById[line.productId]?.name ?? '—',
                        unit: productsById[line.productId]?.unit.short ?? '',
                        quantity: line.quantity,
                        days: line.days,
                        subtotal: line.subtotal,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PayViaUpiButton extends ConsumerWidget {
  const _PayViaUpiButton({required this.amount, required this.note});
  final double amount;
  final String note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final settings = ref.watch(milkmanSettingsProvider);
    if (amount <= 0) return const SizedBox.shrink();
    if (!settings.hasUpi) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          t.t('upi_not_configured'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.outline,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => _pay(context, settings),
        icon: const Icon(Icons.payment),
        label: Text('${t.t('pay_via_upi')} · ₹${amount.toStringAsFixed(2)}'),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.green.shade700,
        ),
      ),
    );
  }

  Future<void> _pay(BuildContext context, MilkmanSettings settings) async {
    final t = AppLocalizations.of(context);
    final ok = await UpiLink.launch(
      vpa: settings.upiId!,
      name: settings.upiPayeeName ?? 'Milkman',
      amount: amount,
      note: note,
    );
    if (!ok && context.mounted) {
      // No UPI app — show the ID so customer can copy it.
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(t.t('pay_via_upi')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.t('pay_to_upi_id')),
              const SizedBox(height: 8),
              SelectableText(
                settings.upiId!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${t.t('amount')}: ₹${amount.toStringAsFixed(2)}',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t.t('cancel')),
            ),
          ],
        ),
      );
    }
  }
}

class _ProductBillLine extends StatelessWidget {
  const _ProductBillLine({
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.days,
    required this.subtotal,
  });

  final String productName;
  final String unit;
  final double quantity;
  final int days;
  final double subtotal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(productName,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('$days days · ${quantity.toStringAsFixed(2)} $unit',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Text('₹${subtotal.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SpendTracker extends ConsumerWidget {
  const _SpendTracker({required this.flatId, required this.anchor});
  final String flatId;
  final DateTime anchor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final repo = ref.watch(deliveryRepositoryProvider);
    final months = repo.recentMonths(flatId, 6, anchor);
    final maxAmount = months.fold<double>(
        0, (m, s) => s.totalAmount > m ? s.totalAmount : m);
    if (maxAmount <= 0) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.t('spend_last_6_months'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final m in months)
                    Expanded(
                      child: _Bar(
                        amount: m.totalAmount,
                        max: maxAmount,
                        label: '${m.monthKey.substring(5)}',
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar(
      {required this.amount, required this.max, required this.label});
  final double amount;
  final double max;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final h = max <= 0 ? 0.0 : (amount / max) * 90;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (amount > 0)
            Text(
              '₹${amount.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 10),
            ),
          const SizedBox(height: 2),
          Container(
            height: h.clamp(2, 90),
            width: double.infinity,
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(amount > 0 ? 0.7 : 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}
