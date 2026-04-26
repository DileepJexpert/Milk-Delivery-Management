import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/milkman_absence.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../auth/session_controller.dart';
import 'broadcast_absence_screen.dart';

class ManageAbsencesScreen extends ConsumerWidget {
  const ManageAbsencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final async = ref.watch(absencesForCurrentMilkmanProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.t('manage_absences'))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rows) {
          if (rows.isEmpty) {
            return Center(child: Text(t.t('no_absences')));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _AbsenceCard(absence: rows[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addDialog(context, ref),
        icon: const Icon(Icons.event_busy),
        label: Text(t.t('add_absence')),
      ),
    );
  }

  Future<void> _addDialog(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context);
    final actor = ref.read(sessionControllerProvider).user;
    if (actor == null) return;

    int kindIndex = 0;
    DateTime? singleDay;
    DateTimeRange? range;
    int weekday = DateTime.sunday;
    final reasonC = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(t.t('add_absence')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<int>(
                  segments: [
                    ButtonSegment(
                        value: 0, label: Text(t.t('absence_single_day'))),
                    ButtonSegment(
                        value: 1, label: Text(t.t('absence_range'))),
                    ButtonSegment(
                        value: 2, label: Text(t.t('absence_recurring'))),
                  ],
                  selected: {kindIndex},
                  onSelectionChanged: (s) =>
                      setState(() => kindIndex = s.first),
                ),
                const SizedBox(height: 12),
                if (kindIndex == 0)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(singleDay == null
                        ? t.t('select_dates')
                        : AppDates.dateKey(singleDay!)),
                    onPressed: () async {
                      final r = await showDatePicker(
                        context: ctx,
                        firstDate: DateTime.now()
                            .subtract(const Duration(days: 1)),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)),
                        initialDate: singleDay ?? DateTime.now(),
                      );
                      if (r != null) setState(() => singleDay = r);
                    },
                  ),
                if (kindIndex == 1)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(range == null
                        ? t.t('select_dates')
                        : '${AppDates.dateKey(range!.start)} → ${AppDates.dateKey(range!.end)}'),
                    onPressed: () async {
                      final r = await showDateRangePicker(
                        context: ctx,
                        firstDate: DateTime.now()
                            .subtract(const Duration(days: 1)),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)),
                      );
                      if (r != null) setState(() => range = r);
                    },
                  ),
                if (kindIndex == 2) ...[
                  Text(t.t('select_day_of_week')),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final d in const [
                        DateTime.monday,
                        DateTime.tuesday,
                        DateTime.wednesday,
                        DateTime.thursday,
                        DateTime.friday,
                        DateTime.saturday,
                        DateTime.sunday,
                      ])
                        ChoiceChip(
                          label: Text(_weekdayLabel(t, d)),
                          selected: weekday == d,
                          onSelected: (_) => setState(() => weekday = d),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: reasonC,
                  decoration: InputDecoration(
                      labelText: t.t('absence_reason_hint')),
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

    final repo = ref.read(absenceRepositoryProvider);
    final reason =
        reasonC.text.trim().isEmpty ? null : reasonC.text.trim();
    MilkmanAbsence? created;
    if (kindIndex == 0 && singleDay != null) {
      created = await repo.createRange(
        milkman: actor,
        fromDate: singleDay!,
        toDate: singleDay!,
        reason: reason,
      );
    } else if (kindIndex == 1 && range != null) {
      created = await repo.createRange(
        milkman: actor,
        fromDate: range!.start,
        toDate: range!.end,
        reason: reason,
      );
    } else if (kindIndex == 2) {
      created = await repo.createRecurring(
        milkman: actor,
        dayOfWeek: weekday,
        reason: reason,
      );
    }

    if (created == null) return;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.t('absence_added'))),
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BroadcastAbsenceScreen(absence: created!),
      ),
    );
  }

  static String _weekdayLabel(AppLocalizations t, int weekday) =>
      switch (weekday) {
        DateTime.monday => t.t('monday'),
        DateTime.tuesday => t.t('tuesday'),
        DateTime.wednesday => t.t('wednesday'),
        DateTime.thursday => t.t('thursday'),
        DateTime.friday => t.t('friday'),
        DateTime.saturday => t.t('saturday'),
        DateTime.sunday => t.t('sunday'),
        _ => '?',
      };
}

class _AbsenceCard extends ConsumerWidget {
  const _AbsenceCard({required this.absence});

  final MilkmanAbsence absence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final title = absence.isRecurring
        ? '${t.t('every_week_on')} ${ManageAbsencesScreen._weekdayLabel(t, absence.recurringDayOfWeek ?? DateTime.sunday)}'
        : (absence.fromDateKey == absence.toDateKey
            ? absence.fromDateKey
            : '${absence.fromDateKey} → ${absence.toDateKey}');
    return Card(
      child: ListTile(
        leading: const Icon(Icons.event_busy, color: Colors.orange),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: absence.reason == null
            ? null
            : Text('"${absence.reason}"'),
        trailing: IconButton(
          tooltip: t.t('remove'),
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            final actor = ref.read(sessionControllerProvider).user;
            if (actor == null) return;
            await ref
                .read(absenceRepositoryProvider)
                .delete(absence.id, actor);
          },
        ),
      ),
    );
  }
}
