import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/flat.dart';
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
