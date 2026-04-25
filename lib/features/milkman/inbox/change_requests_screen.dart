import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/whatsapp.dart';
import '../../../data/models/change_request.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../auth/session_controller.dart';

class ChangeRequestsScreen extends ConsumerWidget {
  const ChangeRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final async = ref.watch(pendingChangeRequestsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (rows) {
        if (rows.isEmpty) {
          return Center(child: Text(t.t('no_requests')));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _RequestCard(request: rows[i]),
        );
      },
    );
  }
}

class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.request});

  final ChangeRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final flat = ref.read(flatRepositoryProvider).byId(request.flatId);
    final title = request.type == ChangeRequestType.pause
        ? t.t('pause')
        : '${t.t('quantity_change')} → ${request.newQuantity}L';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Flat ${flat?.flatNumber ?? '?'} · ${request.requestedByName}'),
            const SizedBox(height: 4),
            Text(
              '${t.t('from')} ${request.fromDateKey}  ${t.t('to')} ${request.toDateKey}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (request.note != null) ...[
              const SizedBox(height: 4),
              Text('"${request.note}"',
                  style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: () async {
                    final actor =
                        ref.read(sessionControllerProvider).user!;
                    await ref
                        .read(changeRequestRepositoryProvider)
                        .apply(request, actor);
                  },
                  icon: const Icon(Icons.check),
                  label: Text(t.t('apply')),
                ),
                const SizedBox(width: 8),
                if (flat != null)
                  OutlinedButton.icon(
                    onPressed: () => WhatsAppLink.send(
                      request.requestedByPhone,
                      'Hi ${request.requestedByName}, your request '
                      '(${request.type == ChangeRequestType.pause ? 'pause' : 'quantity ${request.newQuantity}L'}) '
                      'from ${request.fromDateKey} to ${request.toDateKey} is confirmed.',
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
}
