import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/whatsapp.dart';
import '../../../data/models/flat.dart';
import '../../../data/models/milkman_absence.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/repository_providers.dart';

/// Confirmation + WhatsApp broadcast screen shown after a milkman creates an
/// absence. App subscribers will be alerted via the in-app "milkman absent"
/// banner automatically; this screen handles the WhatsApp deep-link list for
/// non-app subscribers.
class BroadcastAbsenceScreen extends ConsumerWidget {
  const BroadcastAbsenceScreen({super.key, required this.absence});

  final MilkmanAbsence absence;

  String _label() {
    if (absence.isRecurring) {
      return 'every weekday ${absence.recurringDayOfWeek}';
    }
    if (absence.fromDateKey == absence.toDateKey) {
      return absence.fromDateKey;
    }
    return '${absence.fromDateKey} to ${absence.toDateKey}';
  }

  String _message() =>
      'Hi, no milk delivery on ${_label()}. Service resumes the next day. — your milkman';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final flatsAsync = ref.watch(flatsForCurrentMilkmanProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.t('confirm_broadcast'))),
      body: flatsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (flats) {
          final nonApp = flats.where((f) => !f.hasApp).toList();
          final appUsers = flats.where((f) => f.hasApp).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.t('broadcast_explainer')),
                      const SizedBox(height: 12),
                      Text('App subscribers: ${appUsers.length}',
                          style: Theme.of(context).textTheme.bodyMedium),
                      Text('Non-app subscribers: ${nonApp.length}',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (nonApp.isNotEmpty) ...[
                FilledButton.icon(
                  onPressed: () async {
                    for (final f in nonApp) {
                      await WhatsAppLink.send(f.ownerPhone, _message());
                    }
                  },
                  icon: const Icon(Icons.send),
                  label: Text(t.t('broadcast_via_whatsapp')),
                ),
                const SizedBox(height: 16),
                ...nonApp.map((f) => _NonAppRow(flat: f, message: _message())),
              ],
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () async {
                  await ref
                      .read(absenceRepositoryProvider)
                      .markNotified(absence.id);
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: Text(t.t('skip_notifications')),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NonAppRow extends StatelessWidget {
  const _NonAppRow({required this.flat, required this.message});

  final Flat flat;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.chat),
        title: Text('Flat ${flat.flatNumber} — ${flat.ownerName}'),
        subtitle: Text(flat.ownerPhone),
        trailing: IconButton(
          icon: const Icon(Icons.send_outlined, color: Colors.green),
          onPressed: () => WhatsAppLink.send(flat.ownerPhone, message),
        ),
      ),
    );
  }
}
