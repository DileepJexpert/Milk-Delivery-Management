import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/utils/date_utils.dart';
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
    final locale = Localizations.localeOf(context).languageCode;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                    '₹${summary.amountDue.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 8),
                  Text('${t.t('total_litres')}: ${summary.totalLitres}L'),
                  Text('${t.t('days_skipped')}: ${summary.daysSkipped}'),
                  Text('${t.t('days_custom')}: ${summary.daysCustom}'),
                  const SizedBox(height: 8),
                  Text(
                      '${t.t('price_per_litre')}: ₹${summary.pricePerLitre.toStringAsFixed(2)}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
