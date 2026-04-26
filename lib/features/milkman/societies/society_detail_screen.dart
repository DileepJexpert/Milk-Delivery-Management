import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../data/models/flat.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../auth/session_controller.dart';
import '../flats/flat_detail_screen.dart';

class SocietyDetailScreen extends ConsumerWidget {
  const SocietyDetailScreen({super.key, required this.societyId});

  final String societyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final society = ref.watch(societyRepositoryProvider).byId(societyId);
    final flats = ref.watch(flatsForSocietyProvider(societyId));

    return Scaffold(
      appBar: AppBar(title: Text(society?.name ?? '')),
      body: flats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rows) {
          if (rows.isEmpty) {
            return Center(child: Text(t.t('no_flats')));
          }
          final active = rows.where((f) => f.status != FlatStatus.stopped).toList();
          final stopped = rows.where((f) => f.status == FlatStatus.stopped).toList();
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final f in active) _FlatTile(f: f),
              if (stopped.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
                  child: Text(
                    t.t('stopped_flats'),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ),
                for (final f in stopped) _FlatTile(f: f),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addFlat(context, ref),
        icon: const Icon(Icons.add),
        label: Text(t.t('add_flat')),
      ),
    );
  }

  Future<void> _addFlat(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context);
    final flatNo = TextEditingController();
    final owner = TextEditingController();
    final phone = TextEditingController();
    final qty = TextEditingController(text: '1.0');
    final price = TextEditingController(text: '60');
    bool hasApp = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(t.t('add_flat')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: flatNo,
                    decoration:
                        InputDecoration(labelText: t.t('flat_number'))),
                const SizedBox(height: 8),
                TextField(
                    controller: owner,
                    decoration: InputDecoration(labelText: t.t('owner_name'))),
                const SizedBox(height: 8),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: t.t('owner_phone')),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: qty,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      InputDecoration(labelText: t.t('default_quantity')),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      InputDecoration(labelText: t.t('price_per_litre')),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: Text(t.t('has_app')),
                  value: hasApp,
                  onChanged: (v) => setState(() => hasApp = v),
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
    if (ok == true && flatNo.text.trim().isNotEmpty) {
      final actor = ref.read(sessionControllerProvider).user;
      await ref.read(flatRepositoryProvider).create(
            societyId: societyId,
            flatNumber: flatNo.text.trim(),
            ownerName: owner.text.trim(),
            ownerPhone: phone.text.trim(),
            hasApp: hasApp,
            defaultQuantity: double.tryParse(qty.text) ?? 1.0,
            pricePerLitre: double.tryParse(price.text) ?? 60.0,
            actor: actor,
          );
    }
  }
}

class _FlatTile extends StatelessWidget {
  const _FlatTile({required this.f});
  final Flat f;

  @override
  Widget build(BuildContext context) {
    final isStopped = f.status == FlatStatus.stopped;
    final isPaused = f.status == FlatStatus.paused;

    Color? chipColor;
    String chipLabel;
    if (isStopped) {
      chipColor = Colors.grey;
      chipLabel = AppLocalizations.of(context).t('flat_status_stopped');
    } else if (isPaused) {
      chipColor = Colors.orange;
      chipLabel = AppLocalizations.of(context).t('flat_status_paused');
    } else {
      chipColor = Colors.green;
      chipLabel = AppLocalizations.of(context).t('flat_status_active');
    }

    return Opacity(
      opacity: isStopped ? 0.55 : 1.0,
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isStopped
                ? Colors.grey.shade300
                : isPaused
                    ? Colors.orange.shade100
                    : null,
            child: Text(f.flatNumber.substring(0, 1)),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  'Flat ${f.flatNumber} · ${f.ownerName}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration: isStopped ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: chipColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: chipColor.withOpacity(0.5)),
                ),
                child: Text(
                  chipLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: chipColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Text(
            '${f.ownerPhone} · ${f.defaultQuantity}L/day · '
            '₹${f.pricePerLitre.toStringAsFixed(0)}/L'
            '${f.hasApp ? " · app" : ""}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FlatDetailScreen(flatId: f.id),
            ),
          ),
        ),
      ),
    );
  }
}
