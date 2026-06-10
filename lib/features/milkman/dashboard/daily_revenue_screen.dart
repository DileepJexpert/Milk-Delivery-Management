import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/date_utils.dart';
import '../../../providers/repository_providers.dart';

class DailyRevenueScreen extends ConsumerStatefulWidget {
  const DailyRevenueScreen({super.key});

  @override
  ConsumerState<DailyRevenueScreen> createState() =>
      _DailyRevenueScreenState();
}

class _DailyRevenueScreenState extends ConsumerState<DailyRevenueScreen> {
  DateTime _date = AppDates.today();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final stats =
        ref.watch(deliveryRepositoryProvider).dailyStats(_date);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(t.t('revenue_dashboard'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() {
                  _date = _date.subtract(const Duration(days: 1));
                }),
              ),
              Expanded(
                child: Text(
                  AppDates.dateKey(_date),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: AppDates.dateKey(_date) ==
                        AppDates.dateKey(AppDates.today())
                    ? null
                    : () => setState(() {
                          _date = _date.add(const Duration(days: 1));
                        }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.t('todays_revenue'),
                      style: TextStyle(color: scheme.onPrimaryContainer)),
                  const SizedBox(height: 4),
                  Text(
                    '₹${stats.revenue.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _StatRow(
            label: t.t('delivered_today'),
            value: '${stats.delivered}',
            icon: Icons.check_circle_outline,
            color: Colors.green,
          ),
          _StatRow(
            label: t.t('skipped_today'),
            value: '${stats.skipped}',
            icon: Icons.cancel_outlined,
            color: Colors.orange,
          ),
          const SizedBox(height: 12),
          Text(t.t('collected_today'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _StatRow(
                    label: t.t('cash_in'),
                    value: '₹${stats.cashIn.toStringAsFixed(2)}',
                    icon: Icons.payments_outlined,
                    color: Colors.green.shade700,
                    flat: true,
                  ),
                  _StatRow(
                    label: t.t('upi_in'),
                    value: '₹${stats.upiIn.toStringAsFixed(2)}',
                    icon: Icons.qr_code,
                    color: Colors.blue,
                    flat: true,
                  ),
                  _StatRow(
                    label: t.t('bank_in'),
                    value: '₹${stats.bankIn.toStringAsFixed(2)}',
                    icon: Icons.account_balance,
                    color: Colors.purple,
                    flat: true,
                  ),
                  const Divider(),
                  _StatRow(
                    label: 'Total',
                    value: '₹${stats.collectedTotal.toStringAsFixed(2)}',
                    icon: Icons.summarize,
                    color: scheme.primary,
                    flat: true,
                    bold: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _StatRow(
            label: t.t('dues_outstanding'),
            value: '₹${stats.duesOutstanding.toStringAsFixed(2)}',
            icon: Icons.warning_amber_outlined,
            color: stats.duesOutstanding > 0 ? Colors.red : Colors.grey,
          ),
          _StatRow(
            label: t.t('wallet_credits_held'),
            value: '₹${stats.walletCreditsHeld.toStringAsFixed(2)}',
            icon: Icons.account_balance_wallet_outlined,
            color: Colors.teal,
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.flat = false,
    this.bold = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool flat;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final body = ListTile(
      contentPadding: flat
          ? const EdgeInsets.symmetric(horizontal: 4)
          : null,
      dense: flat,
      leading: Icon(icon, color: color),
      title: Text(label),
      trailing: Text(
        value,
        style: TextStyle(
          fontSize: bold ? 18 : 16,
          fontWeight: bold ? FontWeight.bold : FontWeight.w600,
          color: color,
        ),
      ),
    );
    return flat ? body : Card(child: body);
  }
}
