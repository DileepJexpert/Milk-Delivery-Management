import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/repository_providers.dart';
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
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final f = rows[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(f.flatNumber.substring(0, 1))),
                  title: Text(
                    'Flat ${f.flatNumber} · ${f.ownerName}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${f.ownerPhone} · ${f.defaultQuantity}L/day · ₹${f.pricePerLitre.toStringAsFixed(0)}/L'
                    '${f.hasApp ? ' · app' : ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FlatDetailScreen(flatId: f.id),
                    ),
                  ),
                ),
              );
            },
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
      await ref.read(flatRepositoryProvider).create(
            societyId: societyId,
            flatNumber: flatNo.text.trim(),
            ownerName: owner.text.trim(),
            ownerPhone: phone.text.trim(),
            hasApp: hasApp,
            defaultQuantity: double.tryParse(qty.text) ?? 1.0,
            pricePerLitre: double.tryParse(price.text) ?? 60.0,
          );
    }
  }
}
