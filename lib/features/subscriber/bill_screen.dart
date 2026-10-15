import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/upi_payment.dart';
import '../../core/utils/whatsapp.dart';
import '../../core/utils/whatsapp_templates.dart';
import '../../data/local/local_store.dart';
import '../../data/models/flat.dart';
import '../../data/models/product.dart';
import '../../data/models/user.dart';
import '../../features/milkman/settings/milkman_settings.dart';
import '../../providers/data_providers.dart';
import '../../providers/repository_providers.dart';
import 'widgets/farm_pantry_cross_sell.dart';

class BillScreen extends ConsumerStatefulWidget {
  const BillScreen({super.key});

  @override
  ConsumerState<BillScreen> createState() => _BillScreenState();
}

class _BillScreenState extends ConsumerState<BillScreen> {
  DateTime _month = AppDates.today();
  bool _showQr = false;

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
    final monthLabel = AppDates.monthLabel(_month, locale: locale);

    // Look up milkman for UPI payee & WhatsApp notifications
    final milkmanSettings = ref.watch(milkmanSettingsProvider);
    final society = flat.societyId != null
        ? ref.read(societyRepositoryProvider).byId(flat.societyId!)
        : null;
    final milkmanRaw =
        society != null ? LocalStore.instance.users.get(society.milkmanId) : null;
    final milkman = milkmanRaw is Map ? AppUser.fromJson(milkmanRaw) : null;
    final milkmanPhone = milkman?.phone ?? '9000000001';
    final milkmanName =
        milkmanSettings.upiPayeeName ?? milkman?.name ?? 'Milterra Dairy';

    final upiVpa = milkmanSettings.upiId ??
        LocalStore.instance.settings.get('custom_upi_vpa') as String? ??
        UpiPayment.defaultVpa;
    final upiNote = 'Milk Bill Flat ${flat.flatNumber} ($monthLabel)';

    final upiUri = UpiPayment.buildUpiUri(
      vpa: upiVpa,
      payeeName: milkmanName,
      amount: summary.totalAmount,
      transactionNote: upiNote,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
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
                monthLabel,
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
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Amount Due',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                        Text(
                          '₹${summary.totalAmount.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: summary.totalAmount > 0
                            ? Colors.amber.shade100
                            : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        summary.totalAmount > 0 ? 'Pending' : 'Settled',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: summary.totalAmount > 0
                              ? Colors.amber.shade900
                              : Colors.green.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Text(
                  '${t.t('days_delivered_label')}: ${summary.daysDelivered}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  '${t.t('days_subscriber_paused')}: ${summary.daysSubscriberPaused}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  '${t.t('days_milkman_absent')}: ${summary.daysMilkmanAbsent}',
                  style: const TextStyle(fontSize: 14),
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
                : Colors.green.withValues(alpha: 0.15),
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

        const SizedBox(height: 16),

        // 1-Tap UPI Payment Section with Dynamic QR
        if (summary.totalAmount > 0) ...[
          Card(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined,
                          color: Colors.indigo),
                      const SizedBox(width: 8),
                      Text(
                        '1-Tap Instant UPI Payment',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Zero transaction fees. Pay directly to your milkman via any UPI app.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.indigo.shade700,
                    ),
                    icon: const Icon(Icons.flash_on, color: Colors.amber),
                    label: const Text(
                      'Pay with Any UPI App (GPay / PhonePe / Paytm)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      final launched = await UpiPayment.launchUpiIntent(
                        vpa: upiVpa,
                        payeeName: milkmanName,
                        amount: summary.totalAmount,
                        transactionNote: upiNote,
                      );
                      if (!launched && context.mounted) {
                        setState(() => _showQr = true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'No UPI app detected. Scan the QR code below instead.'),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: Icon(
                              _showQr ? Icons.qr_code_scanner : Icons.qr_code_2),
                          label: Text(
                              _showQr ? 'Hide QR Code' : 'Show UPI QR Code'),
                          onPressed: () => setState(() => _showQr = !_showQr),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green.shade800),
                        icon: const Icon(Icons.send_outlined, size: 18),
                        label: const Text('Share Receipt'),
                        onPressed: () {
                          final msg = WhatsAppTemplates.paymentConfirmation(
                            flatNumber: flat.flatNumber,
                            month: monthLabel,
                            amount: summary.totalAmount,
                          );
                          WhatsAppLink.send(milkmanPhone, msg);
                        },
                      ),
                    ],
                  ),
                  if (_showQr) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            QrImageView(
                              data: upiUri,
                              version: QrVersions.auto,
                              size: 190,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Scan with GPay, PhonePe, Paytm, or BHIM',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'UPI ID: $upiVpa',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Spend tracker (last 6 months) ─────────────────────────
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
                      productName: productsById[line.productId]?.name ?? '—',
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

        const SizedBox(height: 20),

        // Milterra Farm Pantry Cross-sell
        FarmPantryCrossSell(flat: flat),
      ],
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
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
                        label: m.monthKey.substring(5),
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
  const _Bar({required this.amount, required this.max, required this.label});
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
              color: scheme.primary.withValues(alpha: amount > 0 ? 0.7 : 0.2),
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
