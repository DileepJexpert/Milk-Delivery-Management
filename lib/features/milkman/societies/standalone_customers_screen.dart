import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../data/models/flat.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../auth/session_controller.dart';
import '../flats/flat_detail_screen.dart';

/// Lists flats that have no society — standalone houses, shops, etc.
class StandaloneCustomersScreen extends ConsumerWidget {
  const StandaloneCustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final flats = ref.watch(flatsForCurrentMilkmanProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.t('standalone_customers'))),
      body: flats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rows) {
          final standalone = rows.where((f) => f.isStandalone).toList();
          final active = standalone
              .where((f) => f.status != FlatStatus.stopped)
              .toList();
          final stopped = standalone
              .where((f) => f.status == FlatStatus.stopped)
              .toList();
          if (standalone.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  t.t('no_standalone_customers'),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
            children: [
              for (final f in active) _CustomerTile(f: f),
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
                for (final f in stopped) _CustomerTile(f: f),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addCustomer(context, ref),
        icon: const Icon(Icons.add),
        label: Text(t.t('add_customer')),
      ),
    );
  }

  Future<void> _addCustomer(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context);
    final labelC = TextEditingController();
    final ownerC = TextEditingController();
    final phoneC = TextEditingController();
    final addressC = TextEditingController();
    final qtyC = TextEditingController(text: '1.0');
    final priceC = TextEditingController(text: '60');
    bool hasApp = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: Text(t.t('add_customer')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelC,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: t.t('customer_label'),
                    hintText: t.t('customer_label_hint'),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ownerC,
                  decoration: InputDecoration(labelText: t.t('owner_name')),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phoneC,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: t.t('owner_phone')),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: addressC,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: t.t('address_optional'),
                    hintText: t.t('address_hint'),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: qtyC,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      InputDecoration(labelText: t.t('default_quantity')),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: priceC,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      InputDecoration(labelText: t.t('price_per_litre')),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t.t('has_app')),
                  value: hasApp,
                  onChanged: (v) => setInner(() => hasApp = v),
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

    if (ok != true || labelC.text.trim().isEmpty) return;
    final actor = ref.read(sessionControllerProvider).user;
    await ref.read(flatRepositoryProvider).create(
          societyId: null,
          flatNumber: labelC.text.trim(),
          ownerName: ownerC.text.trim(),
          ownerPhone: phoneC.text.trim(),
          hasApp: hasApp,
          addressLine: addressC.text.trim().isEmpty
              ? null
              : addressC.text.trim(),
          defaultQuantity: double.tryParse(qtyC.text) ?? 1.0,
          pricePerLitre: double.tryParse(priceC.text) ?? 60.0,
          actor: actor,
        );
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({required this.f});
  final Flat f;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final isStopped = f.status == FlatStatus.stopped;
    final isPaused = f.status == FlatStatus.paused;

    Color chipColor;
    String chipLabel;
    if (isStopped) {
      chipColor = Colors.grey;
      chipLabel = t.t('flat_status_stopped');
    } else if (isPaused) {
      chipColor = Colors.orange;
      chipLabel = t.t('flat_status_paused');
    } else {
      chipColor = Colors.green;
      chipLabel = t.t('flat_status_active');
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
                    : Theme.of(context).colorScheme.secondaryContainer,
            child: const Icon(Icons.home_outlined),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  '${f.flatNumber} · ${f.ownerName}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration:
                        isStopped ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (f.addressLine != null && f.addressLine!.isNotEmpty)
                Text(f.addressLine!,
                    style: Theme.of(context).textTheme.bodySmall),
              Text(
                '${f.ownerPhone} · ${f.defaultQuantity}L/day · '
                '₹${f.pricePerLitre.toStringAsFixed(0)}/L'
                '${f.hasApp ? " · app" : ""}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
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
