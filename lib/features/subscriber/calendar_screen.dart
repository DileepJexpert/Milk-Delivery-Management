import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/daily_delivery.dart';
import '../../data/models/flat.dart';
import '../../providers/data_providers.dart';

/// 5-week calendar centered on today. Each cell is colored by the day's
/// aggregate delivery status across all the subscriber's products.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final flat = ref.watch(myFlatProvider);
    if (flat == null) return const SizedBox.shrink();
    final historyAsync = ref.watch(deliveriesForFlatProvider(flat.id));

    final today = AppDates.today();
    // 14 days back + 21 forward = 35 cells (5 rows of 7)
    final start = today.subtract(const Duration(days: 14));
    final days = List.generate(35, (i) => start.add(Duration(days: i)));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          AppDates.monthLabel(today,
              locale: Localizations.localeOf(context).languageCode),
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        // Weekday headers
        Row(
          children: [
            for (final h in [
              t.t('mon'),
              t.t('tue'),
              t.t('wed'),
              t.t('thu'),
              t.t('fri'),
              t.t('sat'),
              t.t('sun')
            ])
              Expanded(
                child: Text(
                  h,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        historyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('$e'),
          data: (rows) {
            final byDate = <String, List<DailyDelivery>>{};
            for (final r in rows) {
              byDate.putIfAbsent(r.dateKey, () => []).add(r);
            }
            return GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1.0,
              children: [
                for (final d in days)
                  _DayCell(
                    date: d,
                    isToday: AppDates.dateKey(d) == AppDates.dateKey(today),
                    flat: flat,
                    rows: byDate[AppDates.dateKey(d)] ?? const [],
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        const _Legend(),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.isToday,
    required this.flat,
    required this.rows,
  });

  final DateTime date;
  final bool isToday;
  final Flat flat;
  final List<DailyDelivery> rows;

  @override
  Widget build(BuildContext context) {
    final dateKey = AppDates.dateKey(date);
    final onVacation = flat.isOnVacation(dateKey);
    final scheme = Theme.of(context).colorScheme;
    final today = AppDates.today();
    final isFuture = date.isAfter(today);

    Color bg;
    Color fg = Colors.black87;
    String? icon;
    if (onVacation) {
      bg = Colors.purple.withOpacity(0.25);
      icon = 'beach';
    } else if (rows.isEmpty) {
      bg = isFuture
          ? scheme.surfaceContainerHighest
          : Colors.grey.withOpacity(0.15);
    } else {
      final allDelivered = rows.every(
          (r) => r.status == DeliveryStatus.delivered);
      final anyPaused = rows.any((r) =>
          r.status == DeliveryStatus.paused ||
          r.status == DeliveryStatus.skipped);
      final anyAbsent = rows.any(
          (r) => r.status == DeliveryStatus.milkmanAbsent);
      if (allDelivered) {
        bg = Colors.green.withOpacity(0.30);
      } else if (anyAbsent) {
        bg = Colors.red.withOpacity(0.20);
      } else if (anyPaused) {
        bg = Colors.orange.withOpacity(0.25);
      } else {
        bg = scheme.surfaceContainerHighest;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: isToday
            ? Border.all(color: scheme.primary, width: 2)
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${date.day}',
            style: TextStyle(
              color: fg,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
          if (icon == 'beach')
            const Icon(Icons.beach_access, size: 10, color: Colors.purple),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        _LegendDot(
          color: Colors.green.withOpacity(0.30),
          label: t.t('delivered'),
        ),
        _LegendDot(
          color: Colors.orange.withOpacity(0.25),
          label: t.t('paused'),
        ),
        _LegendDot(
          color: Colors.red.withOpacity(0.20),
          label: t.t('milkman_absent'),
        ),
        _LegendDot(
          color: Colors.purple.withOpacity(0.25),
          label: t.t('on_vacation'),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
