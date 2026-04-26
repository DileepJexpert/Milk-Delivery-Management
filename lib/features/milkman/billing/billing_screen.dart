import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/whatsapp.dart';
import '../../../data/models/flat.dart';
import '../../../data/repositories/delivery_repository.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/repository_providers.dart';
import '../bill/bill_pdf.dart';

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  DateTime _month = AppDates.today();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final flatsAsync = ref.watch(flatsForCurrentMilkmanProvider);
    final repo = ref.watch(deliveryRepositoryProvider);
    final locale = Localizations.localeOf(context).languageCode;

    return flatsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (flats) {
        if (flats.isEmpty) {
          return Center(child: Text(t.t('no_flats')));
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
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
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
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
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: flats.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _BillCard(
                  flat: flats[i],
                  summary: repo.summary(flats[i].id, _month),
                  month: _month,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BillCard extends ConsumerWidget {
  const _BillCard({
    required this.flat,
    required this.summary,
    required this.month,
  });

  final Flat flat;
  final MonthlySummary summary;
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final society = ref.read(societyRepositoryProvider).byId(flat.societyId);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Flat ${flat.flatNumber} · ${flat.ownerName}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(society?.name ?? '',
                style: Theme.of(context).textTheme.bodySmall),
            const Divider(height: 16),
            _kv('${t.t('days_delivered_label')} (billable): ',
                '${summary.daysDelivered} · ${summary.totalLitres}L'),
            _kv('${t.t('days_subscriber_paused')}: ',
                '${summary.daysSubscriberPaused}'),
            _kv('${t.t('days_milkman_absent')}: ',
                '${summary.daysMilkmanAbsent}'),
            _kv('${t.t('days_custom')}: ', '${summary.daysCustom}'),
            const SizedBox(height: 8),
            Text(
              '${t.t('total_amount')}: ₹${summary.amountDue.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => BillPdf.shareInvoice(
                    flat: flat,
                    society: society,
                    summary: summary,
                    month: month,
                  ),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: Text(t.t('export_pdf')),
                ),
                OutlinedButton.icon(
                  onPressed: () => WhatsAppLink.send(
                    flat.ownerPhone,
                    'Hi ${flat.ownerName}, your milk bill for '
                    '${month.year}-${month.month.toString().padLeft(2, '0')}: '
                    '${summary.totalLitres}L = ₹${summary.amountDue.toStringAsFixed(2)}',
                  ),
                  icon: const Icon(Icons.send_outlined),
                  label: Text(t.t('whatsapp_notify')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [Text(k), Text(v)]),
      );
}
