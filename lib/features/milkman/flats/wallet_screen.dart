import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/wallet_transaction.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../auth/session_controller.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key, required this.flatId});

  final String flatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final flat = ref.watch(flatRepositoryProvider).byId(flatId);
    final txnsAsync = ref.watch(walletTxnsForFlatProvider(flatId));

    if (flat == null) {
      return const Scaffold(body: Center(child: Text('Flat not found')));
    }

    final balanceColor = flat.walletBalance < 0
        ? Colors.red
        : flat.walletBalance < 100
            ? Colors.orange
            : Colors.green;

    return Scaffold(
      appBar: AppBar(
        title: Text('${t.t('wallet')} · Flat ${flat.flatNumber}'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _topup(context, ref),
        icon: const Icon(Icons.add_card),
        label: Text(t.t('wallet_topup')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        children: [
          Card(
            color: balanceColor.withOpacity(0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: balanceColor.withOpacity(0.4)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.t('wallet_balance'),
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 8),
                  Text(
                    '₹${flat.walletBalance.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: balanceColor,
                    ),
                  ),
                  if (flat.walletBalance < 0)
                    Text(t.t('insufficient_balance'),
                        style: TextStyle(color: balanceColor)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(t.t('wallet_history'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          txnsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('$e'),
            data: (rows) {
              if (rows.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child:
                      Text(t.t('no_wallet_txns'), textAlign: TextAlign.center),
                );
              }
              return Column(
                children: [for (final r in rows) _TxnTile(t: r)],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _topup(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context);
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.t('wallet_topup')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: t.t('topup_amount')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonCtrl,
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
    final amount = double.tryParse(amountCtrl.text);
    if (amount == null || amount <= 0) return;
    final actor = ref.read(sessionControllerProvider).user!;
    final flat = ref.read(flatRepositoryProvider).byId(flatId);
    if (flat == null) return;
    await ref.read(walletRepositoryProvider).topup(
          flat,
          actor,
          amount,
          reason: reasonCtrl.text.trim().isEmpty
              ? null
              : reasonCtrl.text.trim(),
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.t('topup_added'))),
      );
    }
  }
}

class _TxnTile extends StatelessWidget {
  const _TxnTile({required this.t});
  final WalletTxn t;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    Color color;
    IconData icon;
    String prefix;
    String label;
    switch (t.type) {
      case WalletTxnType.topup:
        color = Colors.green;
        icon = Icons.add_card;
        prefix = '+';
        label = loc.t('wallet_topup');
        break;
      case WalletTxnType.debit:
        color = Colors.red;
        icon = Icons.shopping_cart;
        prefix = '−';
        label = loc.t('auto_debit_delivery');
        break;
      case WalletTxnType.refund:
        color = Colors.blue;
        icon = Icons.replay;
        prefix = '+';
        label = loc.t('wallet_refund');
        break;
    }

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${AppDates.prettyDate(t.timestamp, locale: Localizations.localeOf(context).languageCode)}'
              '  ${TimeOfDay.fromDateTime(t.timestamp).format(context)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text('${loc.t('by')} ${t.actorName}',
                style: Theme.of(context).textTheme.bodySmall),
            if (t.reason != null && t.reason!.isNotEmpty)
              Text('"${t.reason}"',
                  style: const TextStyle(
                      fontStyle: FontStyle.italic, fontSize: 12)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$prefix₹${t.amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text('₹${t.balanceAfter.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
